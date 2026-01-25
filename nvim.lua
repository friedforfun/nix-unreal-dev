vim.api.nvim_create_user_command("CopyPath", function()
	local path = vim.fn.expand("%:p")
	vim.fn.setreg("+", path)
	vim.notify("Copied: " .. path)
end, {})

local clang_path = vim.fn.getenv("CLANGD_QUERY_DRIVER")
if clang_path and clang_path ~= "" then
	vim.lsp.config("clangd", {
		cmd = { "clangd", "--query-driver=" .. clang_path },
	})
	vim.lsp.enable("clangd")
end

local dap = require("dap")

-- Configure the GDB adapter (only if not already configured globally)
if not dap.adapter.lldb then
  dap.adapters.lldb = {
    type = "executable",
    command = "lldb-dap",
    name = "lldb",
  }
end

-- Configure the GDB adapter (only if not already configured globally)
if not dap.adapters.gdb then
	dap.adapters.gdb = {
		id = "gdb",
		type = "executable",
		command = "gdb",
		args = { "--quiet", "--interpreter=dap" },
	}
end

-- Project-specific launch configuration
dap.configurations.c = dap.configurations.c or {}
dap.configurations.cpp = dap.configurations.cpp or {}

local function get_project_info()
	-- Expect this function is executed in the same
	-- directory as the .uproject file.
	local uproject_files = vim.fn.glob("*.uproject", false, true)

	if #uproject_files == 0 then
		vim.notify("No .uproject file found in project root.", vim.log.levels.ERROR)
		return nil
	end

	-- Assume that only a single .uproject exists in the
	-- project directory
	local uproject_path = vim.fn.fnamemodify(uproject_files[1], ":p")

	local file = io.open(uproject_path, "r")
	if not file then
		vim.notify("Could not read .uproject file", vim.log.levels.ERROR)
		return nil
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		vim.notify("Failed to parse .uproject file", vim.log.levels.ERROR)
		return nil
	end

	-- Extract project name from JSON with filename fallback
	local project_name = data.Name or vim.fn.fnamemodify(uproject_path, ":t:r")

	return { name = project_name, path = uproject_path }
end

local project_info = get_project_info()
if not project_info then
	return -- Exit early if project not found.
end

local engine_root = vim.fn.getenv("UNREAL_ENGINE_PATH")

-- Avalible Make targets
local targets = {
	project_info.name .. "Editor-Linux-DebugGame",
	project_info.name .. "-Linux-DebugGame",
	project_info.name .. "Editor-Linux-Development",
	project_info.name .. "-Linux-Shipping",
}

local binaries = {
	"UnrealEditor-Linux-DebugGame",
	"Unreal-Linux-DebugGame",
	"UnrealEditor-Linux-Development",
	"Unreal-Linux-Shipping",
}

vim.api.nvim_create_user_command("MakeTarget", function()
	local choice = vim.fn.inputlist({
		"Select build target:",
		"1. " .. targets[1],
		"2. " .. targets[2],
		"3. " .. targets[3],
		"4. " .. targets[4],
	})
	if choice >= 1 and choice <= #targets then
		vim.cmd("Dispatch make " .. targets[choice])
	end
end, {})

for _, target in ipairs(targets) do
	local cmd_name = "Make" .. target:gsub(project_info.name, ""):gsub("-", "")

	vim.api.nvim_create_user_command(cmd_name, function()
		vim.cmd("Dispatch make " .. target)
	end, {})
end

for idx, target in ipairs(targets) do
	table.insert(
		dap.configurations.cpp,
		setmetatable({
			name = target,
			type = "lldb",
			request = "launch",
			program = engine_root .. "/Engine/Binaries/Linux/" .. binaries[idx],
			args = {
				"-project=" .. project_info.path,
			},
			cwd = vim.fn.getcwd(),
      stopCommands = {
        "process handle SIGSEGV --pass true --stop true --notify true",
      },
			_target = target,
		}, {
			__call = function(config)
				vim.notify("Building target: " .. config._target .. "...", vim.log.levels.INFO)

				vim.cmd("!" .. "cd " .. vim.fn.getcwd() .. " && make " .. config._target)

				if vim.v.shell_error ~= 0 then
					vim.notify("Build failed.", vim.log.levels.ERROR)
					return nil
				end

				vim.notify("✓ Build successful! Launching debugger...", vim.log.levels.INFO)
				return config
			end,
		})
	)
end

table.insert(dap.configurations.cpp, {
	name = "Attach to UnrealEditor",
	type = "lldb",

	request = "attach",
	pid = require("dap.utils").pick_process,
})

-- Generate MakeFile command

local function make_cmd()
	return engine_root .. "/Engine/Build/BatchFiles/Linux/Build.sh " .. project_info.path .. " -game -engine -Makefile"
end

vim.api.nvim_create_user_command("UpdateMakeFile", function()
	vim.cmd("Dispatch " .. make_cmd())
end, {})

-- Generate compile_commands.json
local compile_cmd_targets = {
	project_info.name .. " Linux DebugGame",
	project_info.name .. "Editor Linux DebugGame",
	project_info.name .. " Linux Development",
	project_info.name .. "Editor Linux Development",
	project_info.name .. " Linux Shipping",
}

local function make_compile_cmd(target)
	return engine_root
		.. "/Engine/Build/BatchFiles/Linux/Build.sh "
		.. target
		.. " "
		.. project_info.path
		.. " -game -engine -mode=GenerateClangDatabase && cp "
		.. engine_root
		.. "/compile_commands.json ."
end

for _, target in ipairs(compile_cmd_targets) do
	local cmd_name = "UpdateCommands" .. target:gsub(project_info.name, ""):gsub(" ", "")

	vim.api.nvim_create_user_command(cmd_name, function()
		vim.cmd("Dispatch " .. make_compile_cmd(target))
	end, {})
end

vim.api.nvim_create_user_command("GenerateProjectFiles", function()
	vim.cmd("Dispatch " .. make_cmd() .. " && " .. make_compile_cmd(compile_cmd_targets[2]))
end, {})
