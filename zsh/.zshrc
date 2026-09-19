#
# ~/.zshrc
#

[[ $- != *i* ]] && return   # not interactive: nothing below applies

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

autoload -Uz colors && colors
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias leetcode="nvim leetcode.nvim"
PROMPT='[%n@%m %1~]%# '

# Fish-style suggestions as you type. #6c7086 (Catppuccin Mocha overlay0) is
# the same muted grey kitty/mocha.conf uses for inactive/secondary UI, so the
# ghost text reads as "not yet real" rather than a mismatched theme color.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'

# Must be sourced last: it wraps zle widgets, and anything sourced after it
# is invisible to that wrapping.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
