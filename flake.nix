{
  description = "Collection of flake templates";

  outputs = { self }: {
    templates = {
      
      basic = {
        path = ./basic;
        description = "A simple default devShell";
      };

      ros-humble = {
        path = ./ros/humble;
        description = "ROS Humble development environment";
      };

      rust-basic = {
        path = ./rust/rust-basic;
        description = "Basic Rust development environment";
      };

      rust-python-javascript = {
        path = ./rust/rust-python-javascript;
        description = "Compound Rust, Python, JavaScript development environment";
      };
    };

    # Optional: Set a default template
    defaultTemplate = self.templates.basic;
  };
}
# Usage: nix flake init -t <repo>#basic
