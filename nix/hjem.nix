{
  lib,
  ...
}:
let
  profiles = import ../lib/profiles.nix { inherit lib; };

  nonoProfilesModule =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.nono.profiles;
      allProfiles = profiles // cfg.extra;
    in
    {
      options.nono.profiles = {
        enable = lib.mkEnableOption "nono profiles in the nono config directory";

        user = lib.mkOption {
          type = lib.types.str;
          description = "hjem user whose home receives the profiles.";
        };

        extra = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "Additional profiles, keyed by nono profile name.";
        };
      };

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = !cfg.enable || options ? hjem;
              message = "nono.profiles.enable requires hjem to be imported.";
            }
          ];
        }
        (lib.mkIf (cfg.enable && options ? hjem) {
          hjem.users.${cfg.user}.files = lib.mapAttrs' (
            name: path:
            lib.nameValuePair ".config/nono/profiles/${name}.json" {
              source = path;
            }
          ) allProfiles;
        })
      ];
    };
in
{
  flake.nixosModules.default = nonoProfilesModule;
  flake.nixosModules.hjem = nonoProfilesModule;
}
