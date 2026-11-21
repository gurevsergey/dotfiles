function wsport --description 'termshark filtered to a port. Usage: wsport <port> [display-filter] [extra tshark-args...]'
    if test (count $argv) -lt 1
        echo "usage: wsport <port> [display-filter] [extra tshark-args...]" >&2
        return 1
    end
    set -l port $argv[1]
    set -l rest $argv[2..-1]

    set -l iface (_ws_default_iface)
    if test -z "$iface"
        echo "wsport: no active interface detected. Available:" >&2
        wsifaces
        return 1
    end

    if test (count $rest) -gt 0
        termshark -i $iface -f "port $port" -Y "$rest[1]" $rest[2..-1]
    else
        termshark -i $iface -f "port $port"
    end
end
