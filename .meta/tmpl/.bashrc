source /etc/profile.d/bash_completion.sh

eval "$(direnv hook bash)"
eval "$(starship init bash)"

eval $(ssh-agent);
ssh-add

alias opin='eval $(echo $OP_PASSWORD | op signin $OP_ADDRESS $OP_EMAIL $OP_SECRET_KEY)'
