# nix-unreal-dev

A Nix flake for setting up Unreal Engine development environments. This project provides shell environments with all necessary dependencies for compiling and developing Unreal Engine projects on Linux.

## Quick Start

### Prerequisites

- Nix with flake support enabled
- A local Unreal Engine installation

### First-Time Setup

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd nix-unreal-dev
   ```

2. **Configure your engine path:**
   
   Edit `unreal-versions.nix` and set the `enginePath` for your Unreal Engine installation:

   ```nix
   default = "5_5";
   "5_5" = {
     version = "5.5";
     enginePath = "/path/to/your/UnrealEngine/5.5";
     clangRelativePath = "Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v25_clang-18.1.0-rockylinux8/x86_64-unknown-linux-gnu/bin/clang++";
   };
   ```

   Replace `/path/to/your/UnrealEngine/5.5` with the actual path to your Unreal Engine installation.

3. **Enter the development shell:**
   ```bash
   nix develop
   ```

   This will download and set up all dependencies automatically. You're now ready to develop!

## Usage

### Entering a Development Shell

#### Using the default version (5.5)

```bash
nix develop
```

#### Using a specific engine version

```bash
nix develop .#5_5
```

### Using with nix-shell (Legacy)

If you prefer the traditional `nix-shell` approach:

```bash
nix-shell
```

With a specific version:
```bash
nix-shell unreal.nix --arg paramVersion '"5_5"'
```

## Adding Additional Engine Versions

To support additional Unreal Engine installs:

1. **Edit `unreal-versions.nix`:**
   ```nix
   {
     default = "5_5";
     "5_5" = {
       version = "5.5";
       enginePath = "/path/to/UnrealEngine/5.5";
       clangRelativePath = "Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v25_clang-18.1.0-rockylinux8/x86_64-unknown-linux-gnu/bin/clang++";
     };
     "foo" = { # Any name can be used
       version = "5.4";
       enginePath = "/path/to/UnrealEngine/5.4";
       clangRelativePath = "Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/v24_clang-17.0.6-rockylinux8/x86_64-unknown-linux-gnu/bin/clang++";
     };
   }
   ```

2. **Change the default version (optional):**
   Update the `default` field to switch which named engine install loads by default.

3. **Enter the development shell:**
   ```bash
   nix develop .#foo
   ```

## Configuration Details

### Engine Path

The `enginePath` must point to the root directory of your Unreal Engine installation. This is typically where you can find the `Engine/` directory.

### Clang Path

The `clangRelativePath` is relative to the engine root and points to the Clang++ compiler bundled with Unreal Engine. This path may differ depending on your engine version and platform.


## Environment Variables

When entering the development shell, the following environment variables are automatically configured:

- `CLANGD_QUERY_DRIVER` - Points to the Unreal Engine Clang++ compiler
- `DOTNET_ROOT` - .NET runtime configuration
- `LIBGL_DRIVERS_PATH` - OpenGL driver path
- `EGL_DRIVERS_PATH` - EGL driver path
- `LD_LIBRARY_PATH` - Extended with graphics library paths
- `PYTHONPATH` - Configured for GDB Python pretty-printers

## Troubleshooting

### Engine path not configured error

If you see an error about the engine path not being configured, ensure you've edited `unreal-versions.nix` and set the `enginePath` field to a valid Unreal Engine installation directory.

### Version not found

If you try to use a version that doesn't exist in `unreal-versions.nix`, the shell will fail with a list of available versions. Add the version following the "Adding Additional Engine Versions" section above.

### Clang path errors

Verify that the `clangRelativePath` in `unreal-versions.nix` exists in your Unreal Engine installation. The path structure may differ between engine versions.


