{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  options.services.albyHub = {
    enable = mkEnableOption "Alby Hub service";

    package = mkOption {
      type = types.package;
      default = config.albyHub.pkgs.albyHub;
      description = "The AlbyHub Nix package";
    };

    relay = mkOption {
      type = types.str;
      default = "wss://relay.getalby.com/v1";
      description = "Relay URL";
    };

    jwtSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "JWT secret string (required in HTTP mode)";
    };

    databaseUri = mkOption {
      type = types.str;
      default = "$XDG_DATA_HOME/albyhub/nwc.db";
      description = "SQLite database filename";
    };

    port = mkOption {
      type = types.int;
      default = 8029;
      description = "Port on which the app should listen";
    };

    workDir = mkOption {
      type = types.str;
      default = "$XDG_DATA_HOME/albyhub";
      description = "Directory to store NWC data files";
    };

    logLevel = mkOption {
      type = types.int;
      default = 4;
      description = "Log level for the application (higher is more verbose)";
    };

    autoUnlockPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Unlock password to auto-unlock Alby Hub on startup";
    };

    lnd = {
      enable = mkEnableOption "Enable LND as a backend.";
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "localhost:10009";
        description = "The LND gRPC address";
      };
      certPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tls.cert";
        description = "Path to the LND TLS certificate";
      };
      macaroonPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "admin.macaroon";
        description = "Path to the LND admin macaroon file";
      };
    };

    ldkEsploraServer = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Esplora server to use instead of the default Alby esplora instance.";
    };
  };

  cfg = config.services.albyHub;

  configFile = builtins.toFile ".env" ''
    RELAY=${cfg.relay}
    DATABASE_URI=${cfg.databaseUri}
    PORT=${toString cfg.port}
    WORK_DIR=${cfg.workDir}
    LOG_LEVEL=${toString cfg.logLevel}
    ${optionalString (cfg.jwtSecret != null) "JWT_SECRET=${cfg.jwtSecret}"}
    ${optionalString (cfg.autoUnlockPassword != null) "AUTO_UNLOCK_PASSWORD=${cfg.autoUnlockPassword}"}

    ${optionalString (cfg.ldkEsploraserver != null) "LDK_ESPLORA_SERVER=${cfg.ldkEsploraServer}"}

    ${optionalString (cfg.lnd.enable) "LN_BACKEND_TYPE=LND"}
    ${optionalString (cfg.lnd.address != null) "LND_ADDRESS=${cfg.lnd.address}"}
    ${optionalString (cfg.lnd.certPath != null) "LND_CERT_FILE=${cfg.lnd.certPath}"}
    ${optionalString (cfg.lnd.macaroonPath != null) "LND_MACAROON_FILE=${cfg.lnd.macaroonPath}"}
  '';
in {
  inherit options;

  config = mkIf cfg.enable {
    systemd.services.albyhub = rec {
      wantedBy = [ "multi-user.target" ];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/alby-hub";
        Restart = "always";
        RestartSec = "1s";
      };
    environment = {
      PORT = "${toString cfg.port}";
    };
    };
  };
}
