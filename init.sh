#!/bin/bash

# extract wg config file path, or use default
conf="$(jq -r .config_file_path db/server/global_settings.json || echo /etc/wireguard/wg0.conf)"

# determine interface name from config file (ex: /etc/wireguard/wg0.conf -> wg0)
iface="$(basename "$conf" .conf)"

echo "[WGUI] Using config file: $conf"
echo "[WGUI] Detected interface: $iface"

# manage wireguard stop/start with the container
case $WGUI_MANAGE_START in (1|t|T|true|True|TRUE)
    echo "[WGUI] Bringing up WireGuard interface: $iface"
    wg-quick up "$conf"
    # catches container stop
    trap 'echo "[WGUI] Bringing down WireGuard interface: '"$iface"'"; wg-quick down "$conf"' SIGTERM
esac

# manage wireguard restarts (SOFT RELOAD)
case $WGUI_MANAGE_RESTART in (1|t|T|true|True|TRUE)
    [[ -f $conf ]] || touch "$conf" # inotifyd needs file to exist
    echo "[WGUI] Enabling soft reload watcher on: $conf"
    inotifyd - "$conf":w | while read -r event file; do
        echo "[WGUI] Soft reload triggered by change in: $file"
        # apply config without dropping the interface
        wg syncconf "$iface" <(wg-quick strip "$file")
    done &
esac

./wg-ui &
wait $!
