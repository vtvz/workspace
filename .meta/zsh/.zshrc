ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#555555"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

FZF_BASE="/usr/share/fzf/"
DISABLE_FZF_AUTO_COMPLETION="false"

sed -i -E "s/plugins=\\(.*\\)/plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-vim-mode fzf)/" ~/.zshrc_original

source ~/.zshrc_original

bindkey '^H' backward-kill-word

setopt histignorealldups sharehistory
setopt histignorespace

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_tmp/history

autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit && compinit

eval "$(direnv hook zsh)"
eval "$(starship init zsh)"

complete -o nospace -C /usr/local/bin/terraform terraform tf
complete -C /usr/local/bin/aws_completer aws

alias tf=terraform
alias k=kubectl
compdef __start_kubectl k

if [[ -n "$AWS_VAULT" ]]; then
  echo -ne "\033]30;$AWS_VAULT\007"
fi

function zsh-notify-after-command() {
  tput bel
}

autoload -U add-zsh-hook
add-zsh-hook precmd zsh-notify-after-command

alias opin='eval $(echo $OP_PASSWORD | op signin $OP_ADDRESS $OP_EMAIL $OP_SECRET_KEY)'

source /opt/google-cloud-sdk/completion.zsh.inc
