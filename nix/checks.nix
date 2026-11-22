{
  lib,
  ...
}:
let
  profiles = import ../lib/profiles.nix { inherit lib; };
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      profileNames = lib.attrNames profiles;
    in
    {
      checks = {
        profiles =
          pkgs.runCommand "nono-profiles-check"
            {
              nativeBuildInputs = [ pkgs.nono ];
            }
            ''
              export HOME=$TMPDIR/home
              export XDG_CONFIG_HOME=$TMPDIR/config
              export XDG_STATE_HOME=$TMPDIR/state
              export XDG_CACHE_HOME=$TMPDIR/cache
              mkdir -p "$HOME" "$XDG_CONFIG_HOME/nono/profiles"

              cp ${../profiles}/*.json "$XDG_CONFIG_HOME/nono/profiles/"

              ${lib.concatMapStringsSep "\n" (name: ''
                nono profile validate ${lib.escapeShellArg name}
              '') profileNames}

              touch $out
            '';

        nonocode = config.packages.nonocode;
      };
    };
}
