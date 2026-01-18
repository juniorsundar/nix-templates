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

    };

    # Optional: Set a default template
    defaultTemplate = self.templates.basic;
  };
}
# Usage: nix flake init -t <repo>#basic
