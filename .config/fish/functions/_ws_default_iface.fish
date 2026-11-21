function _ws_default_iface --description 'Internal: first non-loopback UP interface'
    ip -brief link 2>/dev/null | awk '$1 != "lo" && $2 == "UP" {print $1; exit}'
end
