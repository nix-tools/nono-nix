{
  inputs,
  ...
}:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";

      programs.nixfmt.enable = true;
      programs.mdformat.enable = true;
      programs.jsonfmt.enable = true;

      settings.excludes = [ "flake.lock" ];
    };
  };
}
