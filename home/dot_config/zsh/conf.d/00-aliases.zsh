alias relogin='exec $SHELL -l'
# GNU lsなら --color、ダメ（BSD/macOS）なら -G で色付け
if ls --color=auto -d . >/dev/null 2>&1; then
  alias ll='ls --color=auto -la'
else
  alias ll='ls -G -la'
fi
alias gd='git diff'
alias gs='git status'
