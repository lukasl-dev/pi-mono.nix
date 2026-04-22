self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.pi.coding-agent;

  environmentFiles = lib.optionalAttrs (lib.isAttrs cfg.environment) cfg.environment;
  rulesPath = if cfg.rules == null then null else pkgs.writeText "pi-AGENTS.md" cfg.rules;

  pathFlags =
    flag: paths:
    lib.concatMap (path: [
      flag
      (toString path)
    ]) paths;

  resourceArgs =
    (lib.optionals (rulesPath != null) [
      "--append-system-prompt"
      (toString rulesPath)
    ])
    ++ pathFlags "--skill" cfg.skills
    ++ pathFlags "--extension" cfg.extensions
    ++ pathFlags "--theme" cfg.themes
    ++ pathFlags "--prompt-template" cfg.promptTemplates;

  wrapperPrelude = lib.optionalString (cfg.environment != null) (
    if lib.isAttrs cfg.environment then
      lib.concatLines (
        lib.mapAttrsToList (name: path: ''
          export ${name}="$(cat ${lib.escapeShellArg (toString path)})"
        '') environmentFiles
      )
    else
      ''
        set -a
        . ${lib.escapeShellArg (toString cfg.environment)}
        set +a
      ''
  );

  wrapperArgs = lib.concatMapStringsSep " " lib.escapeShellArg resourceArgs;
  extraFlagsArgs = lib.concatMapStringsSep " " lib.escapeShellArg cfg.extraFlags;

  wrappedPackage =
    if resourceArgs == [ ] && cfg.environment == null && cfg.extraFlags == [ ] then
      cfg.package
    else
      pkgs.writeShellScriptBin "pi" ''
        ${wrapperPrelude}
        exec ${lib.escapeShellArg (lib.getExe cfg.package)} ${wrapperArgs} ${extraFlagsArgs} "$@"
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
      default = [ ];
      defaultText = lib.literalExpression "[ ] (interpreted as all normal users)";
      description = ''
        Normal users whose `~/.pi/agent` should be managed.

        An empty list means all normal users.
      '';
      example = [ "lukas" ];
    };

    rules = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = ''
        Extra instructions to append to pi's system prompt via `--append-system-prompt`.
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

    promptTemplates = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Prompt template paths to pass to pi via repeated `--prompt-template` flags for every invocation.
      '';
      example = lib.literalExpression ''
        [
          ./prompts
          ./prompt-templates/review.md
        ]
      '';
    };

    models = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a custom `models.json` file to keep at `~/.pi/agent/models.json`.

        This file defines custom providers and models for pi to use.
        When set to `null`, nothing is managed and pi uses its default models.
      '';
      example = lib.literalExpression ''
        ./models.json
      '';
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra raw CLI arguments to always append when launching pi.
      '';
      example = lib.literalExpression ''
        [ "--provider" "openai" "--model" "gpt-5" ]
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
            assertion =
              let
                invalid = builtins.filter (
                  name:
                  !(builtins.hasAttr name (lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users))
                ) cfg.users;
              in
              invalid == [ ];
            message =
              let
                invalid = builtins.filter (
                  name:
                  !(builtins.hasAttr name (lib.filterAttrs (_: user: user.isNormalUser or false) config.users.users))
                ) cfg.users;
              in
              "programs.pi.coding-agent.users contains unknown or non-normal users: ${lib.concatStringsSep ", " invalid}";
          }
          {
            assertion =
              let
                invalid = builtins.filter (name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null) (
                  builtins.attrNames environmentFiles
                );
              in
              invalid == [ ];
            message =
              let
                invalid = builtins.filter (name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null) (
                  builtins.attrNames environmentFiles
                );
              in
              "programs.pi.coding-agent.environment contains invalid environment variable names: ${lib.concatStringsSep ", " invalid}";
          }
        ];

        environment.systemPackages = [ wrappedPackage ];
      }

      (lib.mkIf (cfg.models != null) (
        let
          rules = [
            "d %h/.pi 0700 - - -"
            "d %h/.pi/agent 0700 - - -"
            "L %h/.pi/agent/models.json - - - - ${cfg.models}"
          ];
        in
        lib.mkMerge [
          (lib.mkIf (cfg.users == [ ]) {
            systemd.user.tmpfiles.rules = rules;
          })
          (lib.mkIf (cfg.users != [ ]) {
            systemd.user.tmpfiles.users = builtins.listToAttrs (
              map (name: {
                inherit name;
                value.rules = rules;
              }) cfg.users
            );
          })
        ]
      ))
    ]
  );
}
