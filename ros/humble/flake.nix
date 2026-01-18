{
  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
  };
  outputs =
    {
      self,
      nix-ros-overlay,
      nixpkgs,
    }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-ros-overlay.overlays.default ];
        };

        myRosPackages = with pkgs.rosPackages.humble; [
          rclcpp
          rclpy
          ament-cmake-core
          python-cmake-module
          ros-core
          geographic-msgs
          geometry-msgs
          sensor-msgs
          pluginlib
        ];

        pythonWithRos = pkgs.python3.withPackages (
          ps:
          myRosPackages
          ++ [
            # Add other python deps here if needed, e.g. ps.numpy
          ]
        );

        bearColconAlias = pkgs.writeShellScriptBin "bcb" "bear -- colcon build --symlink-install --base-paths .ros_packages/src --build-base .ros_packages/build --install-base .ros_packages/install --log-base .ros_packages/log --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON";
        colconAlias = pkgs.writeShellScriptBin "cb" "colcon build --symlink-install --base-paths .ros_packages/src --build-base .ros_packages/build --install-base .ros_packages/install --log-base .ros_packages/log --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON";

        pyrightConfigGen = pkgs.writeShellScriptBin "generate-pyright-config" ''
                    echo "Generating pyrightconfig.json..."
                    python3 -c '
          import os, glob, json

          paths = []
          # Local install
          paths.extend(os.path.abspath(p) for p in glob.glob(".ros_packages/install/**/site-packages", recursive=True))
          # Venv
          paths.extend(os.path.abspath(p) for p in glob.glob(".venv/**/site-packages", recursive=True))
          # PYTHONPATH
          pythonpath = os.environ.get("PYTHONPATH", "")
          if pythonpath:
              paths.extend(p for p in pythonpath.split(":") if p)

          config = {
              "include": ["src"],
              "extraPaths": paths,
              "typeCheckingMode": "standard",
              "venvPath": ".",
              "venv": ".venv"
          }
          print(json.dumps(config, indent=2))
          ' > pyrightconfig.json
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "Example project";

          shellHook = ''
            export CC=clang
            export CXX=clang++

            export PYTHONPATH="${pythonWithRos}/${pythonWithRos.sitePackages}:$PYTHONPATH"

            # Setup workspace structure
            mkdir -p .ros_packages/src

            # Link current project
            PROJECT_NAME=$(basename "$PWD")
            # Force update the symlink to point to current directory
            ln -sfn "$PWD" ".ros_packages/src/$PROJECT_NAME"

            # Generate pyright config if it doesn't exist or is empty
            if [ ! -s pyrightconfig.json ]; then
              generate-pyright-config
            fi

            if [ ! -d ".venv" ]; then
              echo "Creating virtual environment..."
              uv venv .venv --system-site-packages
              uv pip install basedpyright ruff
            fi
            source .venv/bin/activate
          '';

          packages = [
            pkgs.uv

            pythonWithRos

            pkgs.colcon
            pkgs.vcstool
            pkgs.eigen
            pkgs.clang
            pkgs.clang-tools
            pkgs.libcxx
            pkgs.gcc
            pkgs.bear
            bearColconAlias
            colconAlias
            pyrightConfigGen

            (pkgs.rosPackages.humble.buildEnv { paths = myRosPackages; })
          ];
        };
      }
    );
  nixConfig = {
    extra-substituters = [ "https://ros.cachix.org" ];
    extra-trusted-public-keys = [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };
}
