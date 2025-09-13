# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-z/zsh-z.plugin.zsh
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

export PATH="$HOME/.local/bin:$PATH"

r() {
  local tmp="$(mktemp -t ranger-cwd.XXXXXX)"
  ranger --choosedir="$tmp" "$@"
  local dir="$(cat "$tmp")"
  [ -d "$dir" ] && cd "$dir"
  rm -f -- "$tmp"
}


# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

path=('/home/tim/.juliaup/bin' $path)
export PATH

# <<< juliaup initialize <<<
#
alias neofetch=fastfetch

autoload -U compinit; compinit
zstyle ':completion:*' menu select
alias vim=nvim
alias vi=nvim
export EDITOR=nvim VISUAL=nvim
alias icat="kitten icat"

export CHEATDIR="$HOME/Documents/Cheatsheets"
export EDITOR_CMD="nvim"
export TERMINAL_CMD="kitty"
export CHEATDIR="$HOME/Documents/Cheatsheets"
export EDITOR_CMD="nvim"
export TERMINAL_CMD="kitty"
export CHEATDIR="$HOME/Documents/Cheatsheets"
export EDITOR_CMD="nvim"
export TERMINAL_CMD="kitty"
export CHEATDIR="$HOME/Documents/Cheatsheets"
export EDITOR_CMD="nvim"
export TERMINAL_CMD="kitty"
