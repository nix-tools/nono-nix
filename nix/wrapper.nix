{
  lib,
  ...
}:
let
  profiles = import ../lib/profiles.nix { inherit lib; };

  mkNonoBox =
    pkgs:
    lib.makeOverridable (
      args:
      let
        inherit (args) name profile;
        tool = args.tool;
        toolBinary = args.toolBinary or tool.meta.mainProgram or name;
        defaultArgs = args.defaultArgs or [ ];
        nonoArgs = args.nonoArgs or [ "--allow-cwd" ];
        homeDirs = args.homeDirs or [ ];
        createDirs = args.createDirs or [ ];
        toolArgHook = args.toolArgHook or "";
        allowRepoRoot = args.allowRepoRoot or true;

        dirs =
          map (dir: "\"$HOME\"/${lib.escapeShellArg dir}") homeDirs
          ++ map (dir: lib.escapeShellArg dir) createDirs;
        mkdirs = lib.optionalString (dirs != [ ]) ("install -d -m 700 ${lib.concatStringsSep " " dirs}\n");
        repoHook = lib.optionalString allowRepoRoot ''
          repo_root=$(git -C . rev-parse --show-toplevel 2>/dev/null || true)
          if [ -n "$repo_root" ] && [ "$repo_root" != "$PWD" ] && [ "$repo_root" != "$HOME" ] && [ "$repo_root" != "/" ]; then
            repo_args+=(--allow "$repo_root")
          fi
        '';
      in
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [
          pkgs.nono
          pkgs.coreutils
          tool
        ]
        ++ lib.optional allowRepoRoot pkgs.gitMinimal;
        text = ''
          ${mkdirs}extra_args=()
          repo_args=()
          ${repoHook}
          ${toolArgHook}
          exec ${lib.getExe pkgs.nono} run ${lib.escapeShellArgs nonoArgs} "''${repo_args[@]}" \
            --profile ${lib.escapeShellArg (toString profile)} -- \
            ${lib.getExe' tool toolBinary} "''${extra_args[@]}" ${lib.escapeShellArgs defaultArgs} "$@"
        '';
      }
    );

  agentDirs = [
    ".local/share/nono-sandbox"
    ".cache/nono-sandbox"
    ".local/state/nono-sandbox"
  ];

  # OpenCode's TUI needs a private server, but its subcommands reject the flag.
  nonocodeHook = ''
    if [ "$#" -eq 0 ] || [ "$1" = "run" ]; then
      extra_args+=(--standalone)
    elif [ "''${1#-}" != "$1" ] && [ "$1" != "--standalone" ]; then
      extra_args+=(--standalone)
    fi
  '';
in
{
  flake.lib = {
    nonoProfiles = profiles;
    inherit mkNonoBox;
  };

  flake.overlays.default = final: prev: {
    nonoProfiles = profiles;
    mkNonoBox = args: mkNonoBox final args;
    nonocode = mkNonoBox final {
      name = "nonocode";
      profile = profiles.opencode;
      tool = final.opencode;
      toolArgHook = nonocodeHook;
      homeDirs = agentDirs;
    };
    nonoclaude = mkNonoBox final {
      name = "nonoclaude";
      profile = profiles.claude;
      tool = final.claude-code;
      toolBinary = "claude";
      homeDirs = agentDirs ++ [ ".local/share/nono-sandbox/claude" ];
    };
  };

  perSystem =
    { pkgs, ... }:
    {
      _module.args.mkNonoBox = mkNonoBox pkgs;

      packages = {
        nonocode = mkNonoBox pkgs {
          name = "nonocode";
          profile = profiles.opencode;
          tool = pkgs.opencode;
          toolArgHook = nonocodeHook;
          homeDirs = agentDirs;
        };
        nonoclaude = mkNonoBox pkgs {
          name = "nonoclaude";
          profile = profiles.claude;
          tool = pkgs.claude-code;
          toolBinary = "claude";
          homeDirs = agentDirs ++ [ ".local/share/nono-sandbox/claude" ];
        };
      };
    };
}
