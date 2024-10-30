
# https://claude.ai/chat/5eb3b570-84ad-443e-ae69-0b1a0793ce69
# USAGE: gitdiffstatus source_commit destination_commit
# Shows files changed only in source, only in destination, and in both
gitdiffstatus() {
    local base=$(git merge-base $1 $2) && echo -e "\nModified in $1 only:" && git diff --name-status $base $1 | grep -v "^C" | sort | uniq | awk '{printf "%-8s %s\n", $1, $2}' && echo -e "\nModified in $2 only:" && git diff --name-status $base $2 | grep -v "^C" | sort | uniq | awk '{printf "%-8s %s\n", $1, $2}' && echo -e "\nModified in both:" && comm -12 <(git diff --name-only $base $1 | sort) <(git diff --name-only $base $2 | sort)
}


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
