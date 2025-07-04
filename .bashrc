# Shell options
shopt -s autocd
shopt -s histappend

# PATH
export PATH="$PATH:$HOME/bin"

# History
export HISTSIZE=5000
export HISTFILESIZE=10000

# Arrow key search bindings
if [[ $- == *i* ]]; then
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi

# Color support
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# Colors for prompt
txtred='\e[0;31m'
txtgrn='\e[0;32m'
bldgrn='\e[1;32m'
bldpur='\e[1;35m'
txtrst='\e[0m'

# Emoji prompt
emojis=("👾" "🌐" "🎲" "🌍" "🐉" "🌵")
EMOJI="${emojis[$RANDOM % ${#emojis[@]}]}"

# Prompt printing
print_before_the_prompt() {
  dir="${PWD/#$HOME/~}"
  printf "\n $txtred%s: $bldpur%s $txtgrn%s\n$txtrst" "$HOSTNAME" "$dir"
}

# PROMPT_COMMAND chain
PROMPT_COMMAND="history -a; history -c; history -r; print_before_the_prompt"

# Final PS1
PS1="$EMOJI > "

# mkdir + cd helper
mkcd() {
  mkdir "$1" && cd "$1"
}

# Aliases
alias l="ls"
alias ll="ls -al"
alias o="xdg-open ."

# Git aliases
alias gaa='git add .'
alias gcm='git commit -m'
alias gpsh='git push'
alias gss='git status -s'
alias gs='echo ""; echo "*********************************************"; echo -e "   DO NOT FORGET TO PULL BEFORE COMMITTING"; echo "*********************************************"; echo ""; git status'
