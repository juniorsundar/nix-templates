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

        bearColconAlias = pkgs.writeShellScriptBin "bcb" "bear -- colcon --log-base .ros_ws/log build --symlink-install --base-paths .ros_ws/src --build-base .ros_ws/build --install-base .ros_ws/install";
        colconAlias = pkgs.writeShellScriptBin "cb" "colcon --log-base .ros_ws/log build --symlink-install --base-paths .ros_ws/src --build-base .ros_ws/build --install-base .ros_ws/install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON";

        pyrightConfigGen = pkgs.writeShellScriptBin "generate-pyright-config" ''
                    echo "Generating pyrightconfig.json..."
                    python3 -c '
          import os, glob, json

          paths = []
          # Local install
          paths.extend(os.path.abspath(p) for p in glob.glob(".ros_ws/install/**/site-packages", recursive=True))
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

        clangdConfigGen = pkgs.writeShellScriptBin "generate-clangd-config" ''
          echo "Generating .clangd..."

          # Start .clangd file
          cat <<EOF > .clangd
          CompileFlags:
            Add:
              - "-std=c++17"
              - "-idirafter"
              - "${pkgs.lib.getDev pkgs.glibc}/include"
              - "-isystem"
              - "${pkgs.lib.getDev pkgs.libcxx}/include/c++/v1"
              - "-isystem"
              - "${pkgs.lib.getDev pkgs.libcxx}/include"
          EOF

          add_paths() {
            local env_var_name=$1
            local env_value=$(eval echo \$$env_var_name)
            
            IFS=':' read -ra PATHS <<< "$env_value"
            for path in "''${PATHS[@]}"; do
              if [ -n "$path" ] && [ -d "$path" ]; then
                echo "    - \"-isystem\"" >> .clangd
                echo "    - \"$path\"" >> .clangd
              fi
            done
          }

          add_paths CPLUS_INCLUDE_PATH
          add_paths CPATH
          add_paths CMAKE_INCLUDE_PATH

          echo "    - \"-isystem\"" >> .clangd
          echo "    - \"$(${pkgs.clang}/bin/clang -print-resource-dir)/include\"" >> .clangd
        '';

        updateRepos = pkgs.writeShellScriptBin "update-repos" ''
          if [ -f repos.repos ]; then
            vcs import .ros_ws/src < repos.repos
          else
            echo "repos.repos not found in the current directory."
          fi
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "Example project";

          shellHook = ''
            export CC=clang
            export CXX=clang++

            export PYTHONPATH="${pythonWithRos}/${pythonWithRos.sitePackages}:$PYTHONPATH"

            mkdir -p .ros_ws/src
            PROJECT_NAME=$(basename "$PWD")
            ln -sfn "$PWD" ".ros_ws/src/$PROJECT_NAME"

            # Generate pyright config if it doesn't exist or is empty
            if [ ! -s pyrightconfig.json ]; then
              generate-pyright-config
            fi

            # Generate clangd config if it doesn't exist or is empty
            if [ ! -s .clangd ]; then
              generate-clangd-config
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
            pkgs.tinyxml-2
            pkgs.clang
            pkgs.clang-tools
            pkgs.libcxx
            pkgs.gcc
            pkgs.bear

            bearColconAlias
            colconAlias
            pyrightConfigGen
            clangdConfigGen
            updateRepos

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
