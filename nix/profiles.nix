{ ... }:
let
  profileDir = ../profiles;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.nono-profiles = pkgs.runCommand "nono-profiles" { } ''
        mkdir -p $out
        cp ${profileDir}/*.json $out/
      '';
    };
}
