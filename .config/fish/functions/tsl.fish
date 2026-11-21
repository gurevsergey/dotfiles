function tsl --description 'Launch termshark live on the active interface. Usage: tsl [iface]'
    set -l iface $argv[1]
    if test -z "$iface"
        set iface (_ws_default_iface)
    end
    if test -z "$iface"
        echo "tsl: no active interface detected, pass one explicitly. Available:" >&2
        wsifaces
        return 1
    end
    termshark -i $iface
end
