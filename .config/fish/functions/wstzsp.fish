function wstzsp --description 'Receive a remote TZSP sniffer stream (MikroTik, Aruba, Colubris, etc). Usage: wstzsp [-i iface] [port] [tshark-args...]'
    set -l args $argv
    set -l port 37008
    # if first remaining (non -i) arg is numeric, treat as the TZSP port
    if test (count $args) -gt 0; and string match -qr '^[0-9]+$' -- $args[1]
        set port $args[1]
        set args $args[2..-1]
    end
    if not contains -- -i $args
        set -l iface (_ws_default_iface)
        if test -n "$iface"
            set args -i $iface $args
        else
            echo "wstzsp: no active interface detected, pass one with -i. Available:" >&2
            wsifaces
            return 1
        end
    end
    tshark --color -f "udp port $port" $args
end
