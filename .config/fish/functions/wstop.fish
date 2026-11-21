function wstop --description 'Top talkers (IP conversations) in a capture file. Usage: wstop <file.pcap>'
    if test (count $argv) -lt 1
        echo "usage: wstop <file.pcap>" >&2
        return 1
    end
    tshark -r $argv[1] -q -z conv,ip
end
