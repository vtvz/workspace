ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#555555"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

FZF_BASE="/usr/share/fzf/"
DISABLE_FZF_AUTO_COMPLETION="false"

sed -i -E "s/plugins=\\(.*\\)/plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf)/" ~/.zshrc_original

source ~/.zshrc_original

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

if [[ -f /opt/google-cloud-sdk/completion.zsh.inc ]]; then
  source /opt/google-cloud-sdk/completion.zsh.inc
fi

alias tf=terraform
alias k=kubectl
compdef k=kubectl

alias opin='eval $(echo $OP_PASSWORD | op signin $OP_ADDRESS $OP_EMAIL $OP_SECRET_KEY)'

# show the active aws-vault profile in the terminal tab title
if [[ -n "$AWS_VAULT" ]]; then
  echo -ne "\033]30;$AWS_VAULT\007"
fi

# ring the terminal bell after every command so inactive tabs flag finished work
function zsh-notify-after-command() {
  tput bel
}

autoload -U add-zsh-hook
add-zsh-hook precmd zsh-notify-after-command

#TODO Review https://unix.stackexchange.com/questions/336680/how-to-execute-command-without-storing-it-in-history-even-for-up-key-in-zsh

bindkey '^H' backward-kill-word

ws-reset-widget () { echo; reset; zle redisplay }

zle -N ws-reset-widget
bindkey '^K' ws-reset-widget

if command -v jump &>/dev/null; then
  eval "$(jump shell)"
fi

[ -f "$HOME/.grit/bin/env" ] && . "$HOME/.grit/bin/env"

export KUBECONFIG="${HOME}/.kube/config-${AWS_VAULT}"
