{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

### NVIDIA-GPU related

{
  imports = [
    # "./nvidia-docker.nix"    # Include the necessary file for Nvidia virtualization (if needed)
    <nixos-hardware/common/gpu/nvidia>
    ../openGL/opengl.nix
    ./included/cachix.nix
    ./nv_vaapi.nix
  ];

  hardware = {
    enableAllFirmware = true;
    # AllowFlipping = "Off";

    nvidia = {
      modesetting.enable = true;
      nvidiaPersistenced = true;

      ### Enable the Nvidia settings menu
      nvidiaSettings = true;

      ### Enable power management
      # powerManagement.enable = true; # Fix Suspend issue
      powerManagement = {
        enable = true;
        finegrained = false;
      };
      prime.offload.enable = false;
      ### Select the appropriate driver version for your GPU
      #package = config.boot.kernelPackages.nvidiaPackages.production;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      vaapi = {
        enable = true;
        firefox.enable = true;
      };

      #---------------------------------------------------------------------
      # Fix screen flipping to black randomly (545x)      
      # (WORKS WELL: 535.86.05 (STABLE) https://download.nvidia.com/XFree86/Linux-x86_64/535.86.05/NVIDIA-Linux-x86_64-535.86.05.run
      # cat /proc/driver/nvidia/version
      #---------------------------------------------------------------------
      # package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs {
      #  src = pkgs.fetchurl {
      #    url = "https://download.nvidia.com/XFree86/Linux-x86_64/535.146.02/NVIDIA-Linux-x86_64-535.146.02.run";
      #   sha256 = sha256_64bit;
      #   sha256 = "49fd1cc9e445c98b293f7c66f36becfe12ccc1de960dfff3f1dc96ba3a9cbf70";
      #   # sha256 = "sha256-QTnTKAGfcvKvKHik0BgAemV3PrRqRlM3B9jjZeupCC8=";
      #  };
      # };
    };
  };

  boot.extraModprobeConfig =
    "options nvidia "
    + lib.concatStringsSep " " [
      # nvidia assume that by default your CPU does not support PAT,
      # but this is effectively never the case in 2023
      "NVreg_UsePageAttributeTable=1"
      # This may be a noop, but it's somewhat uncertain
      "NVreg_EnablePCIeGen3=1"
      # This is sometimes needed for ddc/ci support, see
      # https://www.ddcutil.com/nvidia/
      #
      # Current monitor does not support it, but this is useful for
      # the future
      #"NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
      "NVreg_RegistryDwords=RMI2cSpeed=100"
      # When (if!) I get another nvidia GPU, check for resizeable bar
      # settings
      # Set temporary file path
      "NVreg_TemporaryFilePath=/tmp"
      # Preserve video memory allocations across modesets and VT switches
      "NVreg_PreserveVideoMemoryAllocations=1"
    ];

  # Replace a glFlush() with a glFinish() - this prevents stuttering
  # and glitching in all kinds of circumstances for the moment.
  #
  # Apparently I'm waiting for "explicit sync" support, which needs to
  # land as a wayland thing. I've seen this work reasonably with VRR
  # before, but emacs continued to stutter, so for now this is
  # staying.
  nixpkgs.overlays = [
    (_: final: {
      wlroots_0_16 = final.wlroots_0_16.overrideAttrs (_: {
        patches = [ ./wlroots-nvidia.patch ];
      });
    })
  ];

  # Set environment variables related to NVIDIA graphics
  environment.variables = {
    # Required to run the correct GBM backend for nvidia GPUs on wayland
    GBM_BACKEND = "nvidia-drm";
    # Apparently, without this nouveau may attempt to be used instead
    # (despite it being blacklisted)
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Hardware cursors are currently broken on nvidia
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    __GL_SHADER_CACHE = "1";
    __GL_THREADED_OPTIMIZATION = "1";
  };

  # Specify the Nvidia video driver for Xorg
  services.xserver = {
    videoDrivers = [ "nvidia" ];
    extraConfig = ''
      Section "Device"
         Identifier "Dev0"
         Driver "nvidia"         
         Option "Coolbits" "12"
         Option "TripleBuffer" "True"
         Option "NoLogo" "True"
         Option "UseNvKmsCompositionPipeline" "True"
         Option "UseEDIDFreqs" "True"
         Option "RegistryDwords" "RMUseSwI2c=0x01; RMI2cSpeed=100"
         # solves problem of i2c errors with nvidia driver
         # per https://devtalk.nvidia.com/default/topic/572292/-solved-does-gddccontrol-work-for-anyone-here-nvidia-i2c-monitor-display-ddc/#4309293
      EndSection

      Section "Screen"
        Identifier     "Screen0"
        Device         "Device0"
        Monitor        "Monitor0"
        DefaultDepth    24
        Option         "Stereo" "0"
        Option         "nvidiaXineramaInfoOrder" "HDMI-0"
        Option         "metamodes" "DVI-D-0: 1920x1080_75 +1920+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, HDMI-0: 1920x1080_75 +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
        Option         "SLI" "Off"
        Option         "MultiGPU" "Off"
        Option         "BaseMosaic" "off"
        SubSection     "Display"
        Depth       24
        EndSubSection
      EndSection
    '';
  };

  nix.settings = {
    substituters = [ "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  # Packages related to NVIDIA graphics
  environment.systemPackages = with pkgs; [
    clinfo
    cudaPackages.cudatoolkit
    gwe
    nvtopPackages.nvidia
    virtualglLib
    vulkan-loader
    vulkan-tools
  ];
}

# Notes:

# {
#    version = "555.58";
#    sha256_64bit = "sha256-bXvcXkg2kQZuCNKRZM5QoTaTjF4l2TtrsKUvyicj5ew=";
#    sha256_aarch64 = "sha256-7XswQwW1iFP4ji5mbRQ6PVEhD4SGWpjUJe1o8zoXYRE=";
#    openSha256 = "sha256-hEAmFISMuXm8tbsrB+WiUcEFuSGRNZ37aKWvf0WJ2/c=";
#    settingsSha256 = "sha256-vWnrXlBCb3K5uVkDFmJDVq51wrCoqgPF03lSjZOuU8M=";
#    persistencedSha256 = "sha256-lyYxDuGDTMdGxX3CaiWUh1IQuQlkI2hPEs5LI20vEVw=";
#  }
# turning "allow flipping" off in open GL settings in nvidia has fixed the black screen flicker problem