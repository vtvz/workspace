source /etc/profile.d/bash_completion.sh
source ~/.bashrc_original

eval "$(direnv hook bash)"
eval "$(starship init bash)"

eval $(ssh-agent)
ssh-add

if [[ -e /workspace/.meta/.tflint.hcl ]]; then
  ln -s /workspace/.meta/.tflint.hcl ~/.tflint.hcl
fi

alias tf='terraform'

alias opin='eval $(echo $OP_PASSWORD | op signin $OP_ADDRESS $OP_EMAIL $OP_SECRET_KEY)'
alias tflock='terraform providers lock -platform=darwin_amd64 -platform=linux_amd64'
