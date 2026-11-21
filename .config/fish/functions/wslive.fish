function wslive --description 'Live capture with Wireshark-style colors. Usage: wslive [-i iface] [tshark-args...]'
    set -l args $argv
    if not contains -- -i $args
        set -l iface (_ws_default_iface)
        if test -n "$iface"
            set args -i $iface $args
        else
            echo "wslive: no active interface detected, pass one with -i. Available:" >&2
            wsifaces
            return 1
        end
    end
    tshark --color $args
end
