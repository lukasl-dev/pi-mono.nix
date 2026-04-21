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
  environmentAttrset = if lib.isAttrs cfg.environment then cfg.environment else { };
  invalidEnvironmentNames = builtins.filter (name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null) (builtins.attrNames environmentAttrset);

  resourceArgs =
    (lib.concatMap (path: [ "--skill" (toString path) ]) cfg.skills)
    ++ (lib.concatMap (path: [ "--extension" (toString path) ]) cfg.extensions)
    ++ (lib.concatMap (path: [ "--theme" (toString path) ]) cfg.themes);

  wrapperPrelude =
    lib.optionalString (cfg.environment != null) (
      if lib.isAttrs cfg.environment then
        lib.concatLines (
          lib.mapAttrsToList (name: path: ''
            export ${name}="$(cat ${lib.escapeShellArg (toString path)})"
          '') cfg.environment
        )
      else
        ''
          set -a
          . ${lib.escapeShellArg (toString cfg.environment)}
          set +a
        ''
    );

  wrapperArgs = lib.concatMapStringsSep " " lib.escapeShellArg resourceArgs;

  wrappedPackage =
    if resourceArgs == [ ] && cfg.environment == null then
      cfg.package
    else
      pkgs.writeShellScriptBin "pi" ''
        ${wrapperPrelude}
        exec ${lib.escapeShellArg (lib.getExe cfg.package)} ${wrapperArgs} "$@"
      '';
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
        Skill paths to pass to pi via repeated `--skill` flags for every invocation.
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
        Extension paths to pass to pi via repeated `--extension` flags for every invocation.
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
        Theme paths to pass to pi via repeated `--theme` flags for every invocation.
      '';
      example = lib.literalExpression ''
        [
          ./themes/catppuccin-mocha.json
        ]
      '';
    };

    models = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a custom `models.json` file to symlink to `~/.pi/agent/models.json`.

        This file defines custom providers and models for pi to use.
        When set to `null`, no symlink is created and pi uses its default models.
      '';
      example = lib.literalExpression ''
        ./models.json
      '';
    };

    environment = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path (lib.types.attrsOf lib.types.path));
      default = null;
      description = ''
        Extra environment to set before launching pi.

        This can either be a shell environment file that is sourced with `set -a`,
        or an attribute set mapping environment variable names to files whose contents
        should be exported as the variable values.
      '';
      example = lib.literalExpression ''
        {
          OPENAI_API_KEY = config.age.secrets.openai.path;
          ANTHROPIC_API_KEY = config.age.secrets.anthropic.path;
        }
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
          {
            assertion = invalidEnvironmentNames == [ ];
            message = "programs.pi.coding-agent.environment contains invalid environment variable names: ${lib.concatStringsSep ", " invalidEnvironmentNames}";
          }
        ];

        environment.systemPackages = [ wrappedPackage ];
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


      (lib.mkIf (cfg.models != null) {
        systemd.tmpfiles.settings."10-pi-coding-agent-models" = lib.mkMerge (
          lib.mapAttrsToList (
            _name: user: {
              "${user.home}/.pi/agent/models.json".L = {
                argument = "${cfg.models}";
              };
            }
          ) selectedUsers
        );
      })
    ]
  );
}
