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
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
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
  ]);
}
