# pi-mono.nix

A small Nix flake for [pi](https://github.com/badlogic/pi-mono), the terminal coding agent. It gives you:

- `nix run`
- `nix build`
- a small NixOS module for declarative setup

## Why

The upstream `pi-mono` repo does not ship a `flake.nix`, so this exists to make pi easy to use from Nix without going through npm/node.

See [#2310](https://github.com/badlogic/pi-mono/issues/2310) for context.

## Run

```sh
nix run github:lukasl-dev/pi-mono.nix
```

## Build

```sh
nix build .#coding-agent
```

## NixOS

```nix
# flake.nix
{
  inputs.pi-mono.url = "github:lukasl-dev/pi-mono.nix";
  # ...
}

# pi-mono.nix
{ config, inputs, pkgs, ... }:
{
  imports = [
    inputs.pi-mono.nixosModules.default
  ];

  programs.pi.coding-agent = {
    enable = true;

    # custom package
    # package = inputs.pi-mono.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;

    # target users
    # users = [ "lukas" ]; # defaults to all normal users

    # appended to the system prompt
    # rules = ''
    #   # AGENTS.md
    #   Be concise.
    # '';

    # extra skills
    # skills = [ ./skills/my-skill ];

    # extra extensions
    # extensions = [ ./extensions/my-extension.ts ];

    # extra themes
    # themes = [ ./themes/catppuccin-mocha.json ];

    # extra prompt templates
    # promptTemplates = [ ./prompts ./prompt-templates/review.md ];

    # ~/.pi/agent/models.json
    # models = ./models.json;

    # environment variables or env file
    # environment = {
    #   OPENAI_API_KEY = config.age.secrets.openai.path;
    # };
    # environment = ./pi.env;
  };
}
```

