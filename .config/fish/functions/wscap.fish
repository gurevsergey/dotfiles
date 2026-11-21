function wscap --description 'Capture to a rotating pcapng ring buffer. Usage: wscap <file-prefix> [tshark-args...]'
    if test (count $argv) -lt 1
        echo "usage: wscap <file-prefix> [tshark-args...]" >&2
        return 1
    end
    set -l prefix $argv[1]
    set -l rest $argv[2..-1]
    if not contains -- -i $rest
        set -l iface (_ws_default_iface)
        if test -n "$iface"
            set rest -i $iface $rest
        else
            echo "wscap: no active interface detected, pass one with -i. Available:" >&2
            wsifaces
            return 1
        end
    end
    tshark -w "$prefix.pcapng" -b filesize:102400 -b files:10 $rest
end
