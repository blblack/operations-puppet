RESET="$(tput sgr0)"
BRIGHT="$(tput bold)"
RED="$(tput setaf 1)"
WHITE="$(tput setaf 7)"
export PS1='\u@\[$BRIGHT\]\[$RED\]\h\[$RESET\]:\w\[$BRIGHT\]\[$WHITE\]\$\[$RESET\] '
