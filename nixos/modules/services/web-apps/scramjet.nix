{ config, lib, pkgs, ... }:
let
  cfg = config.services.scramjet;
in
{
  options.services.scramjet = {
    enable = lib.mkEnableOption "Scramjet server";

    package = lib.mkPackageOption pkgs "scramjet" { };

    demoPort = lib.mkOption {
      type = lib.types.port;
      default = 4141;
      description = "Port for the demo web server.";
    };

    wispPort = lib.mkOption {
      type = lib.types.port;
      default = 4142;
      description = "Port for the wisp websocket server.";
    };

    demoHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Host/interface for the demo web server to bind to.";
    };

    wispHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Host/interface for the wisp websocket server to bind to.";
    };

    wispUrl = lib.mkOption {
      type = lib.types.str;
      default = "ws://localhost:4142/";
      example = "wss://example.com/wisp/";
      description = "The URL the browser client will use to connect to the wisp server. Must match how wispPort is reachable externally (e.g. behind a reverse proxy).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "scramjet";
      description = "User to run the service as.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
    };
    users.groups.${cfg.user} = {};

    systemd.services.scramjet = {
      description = "Scramjet server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        DEMO_PORT = toString cfg.demoPort;
        WISP_PORT = toString cfg.wispPort;
        DEMO_HOST = cfg.demoHost;
        WISP_HOST = cfg.wispHost;
        WISP_URL = cfg.wispUrl;
      };

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/scramjet";
        User = cfg.user;
        Group = cfg.user;
        Restart = "on-failure";
        DynamicUser = false;

        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ maartenbehn ];
  };
}
