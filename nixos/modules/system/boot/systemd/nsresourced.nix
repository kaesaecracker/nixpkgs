{ config, lib, ... }:
let

  cfg = config.systemd.nsresourced;

in
{
  options.systemd.nsresourced = {
    enable = lib.mkEnableOption "systemd-nsresourced, the namespace resource manager required for unprivileged (managed) user namespace containers";
  };

  config = lib.mkIf cfg.enable {
    systemd.additionalUpstreamSystemUnits = [
      "systemd-nsresourced.service"
      "systemd-nsresourced.socket"
    ];
    systemd.sockets.systemd-nsresourced.wantedBy = [ "sockets.target" ];
  };
}
