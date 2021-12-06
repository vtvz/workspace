source /etc/profile.d/bash_completion.sh
source ~/.bashrc_original

eval "$(direnv hook bash)"
eval "$(starship init bash)"

eval $(ssh-agent)
ssh-add

if [[ -e /workspace/.meta/.tflint.hcl ]]; then
  ln -s /workspace/.meta/.tflint.hcl ~/.tflint.hcl
fi

alias opin='eval $(echo $OP_PASSWORD | op signin $OP_ADDRESS $OP_EMAIL $OP_SECRET_KEY)'
