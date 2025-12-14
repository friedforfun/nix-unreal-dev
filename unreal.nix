# Version can be specified as parameter, example: $ nix-shell unreal.nix --arg version '"5_5"'
{
  pkgs ? import <nixpkgs> {},
  paramVersion ? null,
}: let
  versions = import ./unreal-versions.nix;

  # Use the param version, or the default.
  version =
    if paramVersion == null
    then versions.default
    else paramVersion;

  # Specified UE version should be part of unreal-versions.nix.
  versionConfig =
    if builtins.hasAttr version versions
    then versions.${version}
    else throw "Unreal path is missing for Unreal Engine Version: ${version}. Avaliable versions: ${builtins.concatStringsSep ", " (builtins.attrNames versions)}";

  # Validate the path is configured
  enginePath =
    if versionConfig.enginePath == null
    then
      throw ''
        Unreal Engine ${versionConfig.version} is not configured.

        Please edit unreal-versions.nix and set:
          - enginePath = "/path/to/engine/${versionConfig.version}"
      ''
    else if !builtins.pathExists versionConfig.enginePath
    then throw "enginePath does not exist: ${versionConfig.enginePath}"
    else versionConfig.enginePath;

  # Find clang++ binary
  sdkPath = "${enginePath}/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64";

  findClangpp = let
    sdkDirs = builtins.readDir sdkPath;

    versionDirs = builtins.filter (name: sdkDirs.${name} == "directory") (builtins.attrNames sdkDirs);

    selectedDir =
      if builtins.length versionDirs > 0
      then builtins.head versionDirs
      else throw "No clang version directories found in ${sdkPath}";
  in "${sdkPath}/${selectedDir}/x86_64-unknown-linux-gnu/clang++";

  clangppPath = findClangpp;

  checkClangpp =
    if !builtins.pathExists clangppPath
    then throw "clang++ not found at ${clangppPath}"
    else null;

  dotnetPkg = with pkgs.dotnetCorePackages;
    combinePackages [
      sdk_9_0
    ];

  fhsEnv = pkgs.buildFHSEnv {
    name = "UnrealEditor";

    targetPkgs = pkgs:
      with pkgs;
        [
          # LLVM toolchain
          clang_18
          clang-tools
          gdb
          python3

          # Dotnet
          dotnet-sdk
          mono

          # Base libraries
          udev
          zlib
          openssl
          icu

          # SDL2 and multimedia
          SDL2
          SDL2.dev
          SDL2_image
          SDL2_ttf
          SDL2_mixer

          # Graphics
          vulkan-loader
          vulkan-tools
          vulkan-validation-layers
          libGL
          libdrm
          mesa

          # Audio/Graphics support
          alsa-lib
          libpulseaudio
          libgbm
          libxkbcommon
          expat
          wayland

          # GUI/Windowing
          glib
          dbus
          pango
          cairo
          atk
          gtk3
          nss
          nspr

          # FAB plugin - zenity
          zenity
        ]
        ++ (with pkgs.xorg; [
          libICE
          libSM
          libX11
          libxcb
          libXcomposite
          libXcursor
          libXdamage
          libXext
          libXfixes
          libXi
          libXrandr
          libXrender
          libXScrnSaver
          libxshmfence
          libXtst
        ]);

    profile = ''
       # Clangd configuration
      export CLANGD_QUERY_DRIVER="${clangppPath}"

       # Dotnet configuration
       export DOTNET_ROOT="${dotnetPkg}"
       export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
       export DOTNET_NUGET_DISABLE_ADVISORY_AUDITABILITY=true

       # Graphics support
       export LIBGL_DRIVERS_PATH="${pkgs.lib.getLib pkgs.mesa}/lib/dri"
       export EGL_DRIVERS_PATH="${pkgs.lib.getLib pkgs.mesa}/lib/egl"
       export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [pkgs.libdrm pkgs.mesa pkgs.libgbm]}:$LD_LIBRARY_PATH"

       # GDB Python pretty-printers
       export PYTHONPATH="${pkgs.gcc}/share/gcc-${pkgs.gcc.version}/python:$PYTHONPATH"
    '';
  };
in
  fhsEnv.env
