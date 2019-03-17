{config, pkgs, ...}:

{
  unstable = import <unstable> {
        config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
            allowBroken = true;
        };
  };
}
