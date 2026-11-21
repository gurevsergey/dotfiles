function wsstats --description 'Protocol hierarchy stats for a capture file. Usage: wsstats <file.pcap>'
    if test (count $argv) -lt 1
        echo "usage: wsstats <file.pcap>" >&2
        return 1
    end
    tshark -r $argv[1] -q -z io,phs
end
