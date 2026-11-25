function gw --description 'Шлюз ПК на MikroTik: gw [domru|london|swe|next|menu]'
    # без аргументов — показать текущий; логика в ~/.local/bin/mkt-gw
    mkt-gw $argv
end
