{
  inputs,
  ...
}:
{
  imports = [ inputs.hk-nix.flakeModules.default ];

  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      treefmt = lib.getExe config.treefmt.build.wrapper;
    in
    {
      hk-nix.settings.hooks = {
        "pre-commit" = {
          fix = true;
          stash = "git";
          steps = {
            treefmt = {
              glob = "**/*";
              check = "${treefmt} --fail-on-change --no-cache {{files}}";
              fix = "${treefmt} {{files}}";
            };

            check-merge-conflict.builtin = config.hk-nix.builtins.check_merge_conflict;
            gitleaks.builtin = config.hk-nix.builtins.gitleaks;
          };
        };

        "commit-msg".steps.conventional.builtin = config.hk-nix.builtins.check_conventional_commit;

        "pre-push".steps = {
          deadnix = {
            glob = "*.nix";
            check = "${lib.getExe pkgs.deadnix} --fail {{files}}";
          };

          flake-check.check = "${lib.getExe pkgs.nix} flake check";
        };
      };
    };
}
