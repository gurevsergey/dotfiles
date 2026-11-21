function ws37008 --description 'termshark on port 37008. Usage: ws37008 [display-filter] [extra tshark-args...]'
    set -l iface (_ws_default_iface)
    if test -z "$iface"
        echo "ws37008: no active interface detected. Available:" >&2
        wsifaces
        return 1
    end

    if test (count $argv) -gt 0
        termshark -i $iface -f "port 37008" -Y "$argv[1]" $argv[2..-1]
    else
        termshark -i $iface -f "port 37008"
    end
end
