if status is-interactive
    # Commands to run in interactive sessions can go here

    # Wireshark/tshark/termshark shortcuts
    abbr -a tsD 'tshark -D'                 # list interfaces
    abbr -a tsr 'tshark -r'                 # read a capture file
    abbr -a tsv 'tshark -v'                 # version info
    abbr -a tsj 'tshark -T json'            # json output
end

# Убрать приветствие (bobthefish задаёт своё)
function fish_greeting
end

# Промпт Starship (перекрывает тему omf)
if status is-interactive; and command -q starship
    starship init fish | source
end
