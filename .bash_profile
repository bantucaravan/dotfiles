


######### Aliases (added by noah) #########

alias off="sudo shutdown -h now"

alias ipython='python -m IPython' # doesn't seem to be available in shell otherwise in some cases?... from https://stackoverflow.com/questions/34441943/ipython-installed-but-not-found


# https://claude.ai/chat/5eb3b570-84ad-443e-ae69-0b1a0793ce69
# USAGE: gitdiffstatus source_commit destination_commit
# Shows files changed only in source, only in destination, and in both
gitdiffstatus() {
    local base=$(git merge-base $1 $2)
    
    echo "Modified in $1 only:"
    # Get files changed only in $1
    files_in_1=$(comm -23 \
        <(git diff --name-only $base $1 | sort) \
        <(git diff --name-only $base $2 | sort))
    if [ ! -z "$files_in_1" ]; then
        git diff --name-status $base $1 -- $files_in_1
    fi
    
    echo
    echo "Modified in $2 only:"
    # Get files changed only in $2
    files_in_2=$(comm -23 \
        <(git diff --name-only $base $2 | sort) \
        <(git diff --name-only $base $1 | sort))
    if [ ! -z "$files_in_2" ]; then
        git diff --name-status $base $2 -- $files_in_2
    fi
    
    echo
    echo "Modified in both:"
    # Get files changed in both
    files_in_both=$(comm -12 \
        <(git diff --name-only $base $1 | sort) \
        <(git diff --name-only $base $2 | sort))
    if [ ! -z "$files_in_both" ]; then
        while IFS= read -r file; do
            status1=$(git diff --name-status $base $1 -- "$file" | cut -f1)
            status2=$(git diff --name-status $base $2 -- "$file" | cut -f1)
            printf "%-8s -> %-8s %s\n" "$status1" "$status2" "$file"
        done <<< "$files_in_both"
    fi
}

alias gs='git status'

######## Aliases (added by noah) END #######


####### Path Extensions ( Noah Added ) ############


# export PATH="$PATH:/usr/local/mysql-5.7.16-osx10.11-x86_64/bin"

# export PATH="$PATH:/Library/Frameworks/R.framework/Resources"

export PATH=$PATH:/Users/admin/.local/bin # old pipenv and virtual env sitting here

# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home/"

# export LD_LIBRARY_PATH=/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home/jre/lib/server

# export DYLD_FALLBACK_LIBRARY_PATH=/Library/Frameworks/R.framework/Resources/lib:/Library/Java/JavaVirtualMachines/jdk1.8.0_221.jdk/Contents/Home/jre/lib/server:$HOME/lib:/usr/local/lib:/lib:/usr/lib

# export CPATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1
# export LIBRARY_PATH=$LIBRARY_PATH:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib
# # It is worth checking to see if this becomes unnecessary after OS is updated past mac os 10.11 (or xcode is installed)

# add homebrew and its installed packages to PATHs and etc (command was recommended by homebrew)
eval "$(/opt/homebrew/bin/brew shellenv)"
# for brew coreutils consider...
# Commands also provided by macOS and the commands dir, dircolors, vdir have been installed with the prefix "g".
# If you need to use these commands with their normal names, you can add a "gnubin" directory to your PATH with:
#   "PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# add homebrew installed python binaries to PATH (one line per interpreter version)
export PATH=$PATH:$HOMEBREW_PREFIX/opt/python@3.9/libexec/bin

# add python.org installed python binaries to PATH (one line per interpreter version)
export PATH=$PATH:/Library/Frameworks/Python.framework/Versions/3.10/bin
export PATH=$PATH:/Library/Frameworks/Python.framework/Versions/3.11/bin


###### Path Extentions (by noah) END ############




# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
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


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/admin/google-cloud-sdk/path.bash.inc' ]; then . '/Users/admin/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/admin/google-cloud-sdk/completion.bash.inc' ]; then . '/Users/admin/google-cloud-sdk/completion.bash.inc'; fi
