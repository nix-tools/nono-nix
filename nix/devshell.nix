{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          config.hk-nix.hk
          pkgs.git
          pkgs.just
          pkgs.jq
          pkgs.nono
        ];

        shellHook = config.hk-nix.shellHook;
      };
    };
}
