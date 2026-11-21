function wsfollow --description 'Follow a TCP stream from a capture file. Usage: wsfollow <file.pcap> <stream-index>'
    if test (count $argv) -lt 2
        echo "usage: wsfollow <file.pcap> <stream-index>" >&2
        return 1
    end
    tshark -r $argv[1] -q -z follow,tcp,ascii,$argv[2]
end
