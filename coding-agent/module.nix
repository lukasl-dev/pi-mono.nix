self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.pi.coding-agent;

  normalUsers = lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users;
  selectedUsers = lib.getAttrs cfg.users normalUsers;
  invalidUsers = builtins.filter (name: !(builtins.hasAttr name normalUsers)) cfg.users;
in
{
  options.programs.pi.coding-agent = {
    enable = lib.mkEnableOption "pi agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;
      defaultText = lib.literalExpression "inputs.pi-mono.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent";
      description = "The pi coding agent package to install.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = builtins.attrNames normalUsers;
      defaultText = lib.literalExpression "builtins.attrNames (lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users)";
      description = ''
        Normal users whose `~/.pi/agent` should be managed.
      '';
      example = [ "lukas" ];
    };

    rules = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = ''
        Content to symlink to `~/.pi/agent/AGENTS.md` for the configured users.
      '';
      example = ''
        # Rules
        - Be concise.
        - Make no mistakes.
      '';
    };

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Skill directories to symlink into `~/.pi/agent/skills/` for the configured
        users.

        Each path is symlinked using its basename as the symlink name.
        The path should be a directory containing a `SKILL.md` file.
      '';
      example = lib.literalExpression ''
        [
          ./skills/my-skill
          ./skills/nixpkgs
        ]
      '';
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Extension files or directories to symlink into `~/.pi/agent/extensions/`
        for the configured users.

        Each path is symlinked using its basename as the symlink name.
      '';
      example = lib.literalExpression ''
        [
          ./extensions/my-extension.ts
        ]
      '';
    };

    themes = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Theme JSON files to symlink into `~/.pi/agent/themes/` for the configured
        users.

        Each path is symlinked using its basename as the symlink name.
      '';
      example = lib.literalExpression ''
        [
          ./themes/catppuccin-mocha.json
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = invalidUsers == [ ];
            message = "programs.pi.coding-agent.users contains unknown or non-normal users: ${lib.concatStringsSep ", " invalidUsers}";
          }
        ];

        environment.systemPackages = [ cfg.package ];
      }

      (lib.mkIf (cfg.rules != null) {
        systemd.tmpfiles.settings."10-pi-coding-agent" =
          let
            rulesFile = pkgs.writeText "pi-AGENTS.md" cfg.rules;
          in
          lib.mkMerge (
            lib.mapAttrsToList (name: user: {
              "${user.home}/.pi".d = {
                user = name;
                inherit (user) group;
                mode = "0700";
              };

              "${user.home}/.pi/agent".d = {
                user = name;
                inherit (user) group;
                mode = "0700";
              };

              "${user.home}/.pi/agent/AGENTS.md".L = {
                argument = "${rulesFile}";
              };
            }) selectedUsers
          );
      })

      (lib.mkIf (cfg.skills != [ ]) {
        systemd.tmpfiles.settings."10-pi-coding-agent-skills" = lib.mkMerge (
          lib.mapAttrsToList (
            _name: user:
            lib.mkMerge [
              {
                "${user.home}/.pi/agent/skills".d = {
                  user = user.name;
                  inherit (user) group;
                  mode = "0755";
                };
              }
              (lib.listToAttrs (
                lib.imap0 (_i: path: {
                  name = "${user.home}/.pi/agent/skills/${lib.strings.unsafeDiscardStringContext (baseNameOf (toString path))}";
                  value.L = {
                    argument = "${path}";
                  };
                }) cfg.skills
              ))
            ]
          ) selectedUsers
        );
      })

      (lib.mkIf (cfg.extensions != [ ]) {
        systemd.tmpfiles.settings."10-pi-coding-agent-extensions" = lib.mkMerge (
          lib.mapAttrsToList (
            _name: user:
            lib.mkMerge [
              {
                "${user.home}/.pi/agent/extensions".d = {
                  user = user.name;
                  inherit (user) group;
                  mode = "0755";
                };
              }
              (lib.listToAttrs (
                lib.imap0 (_i: path: {
                  name = "${user.home}/.pi/agent/extensions/${lib.strings.unsafeDiscardStringContext (baseNameOf (toString path))}";
                  value.L = {
                    argument = "${path}";
                  };
                }) cfg.extensions
              ))
            ]
          ) selectedUsers
        );
      })

      (lib.mkIf (cfg.themes != [ ]) {
        systemd.tmpfiles.settings."10-pi-coding-agent-themes" = lib.mkMerge (
          lib.mapAttrsToList (
            _name: user:
            lib.mkMerge [
              {
                "${user.home}/.pi/agent/themes".d = {
                  user = user.name;
                  inherit (user) group;
                  mode = "0755";
                };
              }
              (lib.listToAttrs (
                lib.imap0 (_i: path: {
                  name = "${user.home}/.pi/agent/themes/${lib.strings.unsafeDiscardStringContext (baseNameOf (toString path))}";
                  value.L = {
                    argument = "${path}";
                  };
                }) cfg.themes
              ))
            ]
          ) selectedUsers
        );
      })
    ]
  );
}
