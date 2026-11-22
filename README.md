# nono-nix

Nix-packaged profiles and wrapper commands for [nono](https://nono.sh).

The profiles are plain JSON in `profiles/`. The flake exposes:

- a generic `mkNonoBox` wrapper builder, in the spirit of bubblebox's `mkBubblebox`
- `nonocode` and `nonoclaude`, two concrete wrappers
- an overlay with `nonoProfiles`, `mkNonoBox`, `nonocode`, and `nonoclaude`
- a NixOS module that uses hjem to install the profiles into `~/.config/nono/profiles`

## Profiles

| Profile | Extends | Purpose |
|------------|-----------|---------|
| `nix-dev` | `default` | Nix development base: host store, daemon, caches, git config |
| `opencode` | `nix-dev` | OpenCode with a sandbox-private data, cache, and state directory |
| `claude` | `nix-dev` | Claude Code with a sandbox-private config, data, cache, and state |

`nix-dev` grants:

- `nix_runtime`: `/nix/store`, `/nix/var/nix/profiles`, `~/.nix-profile`, `/run/current-system/sw`
- `git_config`: `~/.gitconfig`, `~/.config/git/config`, and friends
- `linux_temp_read`: readable `/tmp`, because Bun and friends extract shared libraries there
- `/etc/nix`, `~/.config/nix`, `~/.config/direnv`, and `~/.config/gh/config.yml` read-only
- `~/.cache/nix`, `~/.cache/direnv`, `~/.local/share/nix`, `~/.local/share/direnv`, and `~/.local/state/nix` read-write
- the nix daemon socket at `/nix/var/nix/daemon-socket/socket`
- the working directory read-write

It also strips token, key, secret, password, and credential variables from the inherited environment, together with `SSH_AUTH_SOCK`, `GPG_AGENT_INFO`, `DBUS_SESSION_BUS_ADDRESS`, and inherited OpenCode/Claude agent markers. Nono-injected credentials bypass that deny list, so the credential proxy still works.

The agent profiles do not grant the host agent state. `opencode` sets `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME` to `~/.{local/share,cache,local/state}/nono-sandbox`, and `claude` in addition sets `CLAUDE_CONFIG_DIR` to `~/.local/share/nono-sandbox/claude`. Log in inside the sandbox if you want the agent to have credentials; they stay in the sandbox directory. Host `~/.claude/.credentials.json`, `~/.local/share/opencode/auth.json`, and `~/.config/gh/hosts.yml` remain unreadable.

`opencode` also grants the local plugin repository at `~/Projects/nursery/opencode-plugins` read-only, because the host config symlinks plugins from there. Remove that grant if you package your plugins differently.

## Install

### As a flake input with hjem

```nix
{
  inputs.nono-nix.url = "github:nix-tools/nono-nix";
  inputs.nono-nix.inputs.nixpkgs.follows = "nixpkgs";
}
```

Add `inputs.nono-nix.nixosModules.default` to the NixOS modules list, then:

```nix
{
  nixpkgs.overlays = [ inputs.nono-nix.overlays.default ];

  nono.profiles = {
    enable = true;
    user = "sshine";
    # extra = { my-project = ./my-project.json; };
  };

  environment.systemPackages = [
    pkgs.nonocode
    pkgs.nonoclaude # claude-code is unfree
  ];
}
```

The module writes the profiles through hjem as `~/.config/nono/profiles/<name>.json`. The base `nix-dev` has to be visible this way because `opencode` and `claude` extend it by name.

### Without the NixOS module

Build the profile directory and link it into place:

```sh
mkdir -p ~/.config/nono/profiles
ln -sf "$(nix build --print-out-paths .#nono-profiles)"/*.json ~/.config/nono/profiles/
```

Without Nix at all, copy the JSON files from `profiles/`.

### Overlay only

```nix
nixpkgs.overlays = [ inputs.nono-nix.overlays.default ];
```

That provides `pkgs.nonoProfiles`, `pkgs.mkNonoBox`, `pkgs.nonocode`, and `pkgs.nonoclaude`. The wrappers still need the profiles installed for their `extends` chains.

To use `llm-agents`' OpenCode rather than the nixpkgs one:

```nix
let
  llm-pkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
pkgs.nonocode.override {
  tool = llm-pkgs.opencode2;
  toolBinary = "opencode2";
}
```

## Usage

```sh
nonocode                 # TUI, private server
nonocode --continue      # TUI flags still reach OpenCode
nonocode run "..."       # non-interactive run, private server
nonocode debug paths     # subcommands do not receive --standalone
nonoclaude
```

Wrappers add `--allow-cwd`, so the profile's `workdir.access = "readwrite"` applies without an interactive prompt. They also add the git top-level read-write when you launch them below it, so `git` and the agent see the whole repository. Set `allowRepoRoot = false` to opt out. Git commits work; `git push` needs either the SSH agent socket or a credential file, and the base profile grants neither.

For Nix work with no agent:

```sh
nono run --profile nix-dev --allow-cwd -- nix develop
nono run --profile nix-dev --allow-cwd -- bash
```

Ad-hoc grants use nono's own flags, not a wrapper-specific `--rw`/`--ro`:

```sh
nono run --profile opencode -a ../worktree --allow-cwd -- opencode --standalone
```

The wrappers create the private sandbox directories. If you call `nono run` directly before ever using a wrapper, create them first:

```sh
mkdir -p ~/.local/share/nono-sandbox ~/.cache/nono-sandbox ~/.local/state/nono-sandbox
```

## Credentials

The base profile strips host secrets. To let an agent use an API key through nono's credential proxy instead, extend the agent profile with the service and its host:

```json
{
  "extends": "opencode",
  "network": {
    "credentials": ["openai", "anthropic"],
    "allow_domain": ["api.openai.com", "api.anthropic.com"]
  }
}
```

Nono resolves the real key from its keystore and gives the sandbox a phantom token. The host key never enters the sandbox environment. Check nono's documentation for the service names supported by your version.

The sandboxed Claude starts with an empty config directory. Copy `~/.claude/CLAUDE.md`, settings, or skills into `~/.local/share/nono-sandbox/claude` if you want them there.

## Design notes

- nono already has a `nix_runtime` group that reads `/nix/store`; it is not in `default`. The profile adds that group plus the daemon socket and Nix state.
- bubblebox's empty `$HOME` maps to "grant only these paths". Landlock leaves the denied paths visible, unlike a mount namespace.
- bubblebox hides `/run/user/$UID` by default. In nono, simply do not grant it. Landlock does not mediate `connect(2)` on AF_UNIX sockets, so add `linux.af_unix_mediation = "pathname"` to the profile if you want default-deny sockets, then list the ones you need.
- bubblebox's tmpfs `/tmp` maps to the host `/tmp` read-write. `linux_temp_read` is required because tools such as Bun extract and `dlopen` shared libraries from `/tmp`.
- bubblebox sanitizes `/etc/ssh` because bwrap maps only the invoking uid. nono does not unshare the uid, so the workaround is unnecessary.
- bubblebox's `--rw`/`--ro` are already `-a`/`-r` in nono. The wrapper does not reimplement them.
- `nonocode` adds `--standalone` only for the TUI, `run`, and TUI flags. OpenCode subcommands such as `debug` reject the flag.

## Adding a wrapper

```nix
pkgs.mkNonoBox {
  name = "nonogit";
  profile = pkgs.nonoProfiles.nix-dev;
  tool = pkgs.git;
  toolBinary = "git";
  homeDirs = [ ".local/share/nono-sandbox" ];
}
```

`homeDirs` are created under `$HOME` before nono starts. This is the equivalent of bubblebox's `homeBindings` creation. `nonoArgs` defaults to `["--allow-cwd"]`; `allowRepoRoot` defaults to `true`; `toolArgHook` is an escape hatch for arguments that depend on the tool's first argument.

To add a package to this flake, add an entry under `packages` in `nix/wrapper.nix`.

## Checks

```sh
nix flake check
nix build .#checks.x86_64-linux.profiles
```

The profile check validates every JSON file with the nixpkgs `nono`.
