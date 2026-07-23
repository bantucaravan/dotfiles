#!/bin/bash

# USAGE: git show-changes [<base>] [<feature>] [-- <path>]
# DOC: shows the diff between the merge-base of <base> and <feature>, and <feature>.
# - git show-changes main feature       -> diff from merge-base(main, feature) to feature
# - git show-changes feature            -> same as above, <base> defaults to "main"
# - git show-changes                    -> diff from merge-base(main, HEAD) to the current working tree
# - append `-- path/to/file` to any of the above to restrict the diff to a single file/dir

arg1=""
arg2=""
arg_count=0

# collect up to 2 positional args (base, feature), stopping at "--" if present
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    if [ $arg_count -eq 0 ]; then
        arg1="$1"; arg_count=1
    elif [ $arg_count -eq 1 ]; then
        arg2="$1"; arg_count=2
    fi
    shift
done
[ "$1" = "--" ] && shift
path="${1:-.}"

# feature empty means "diff against the working tree" (git show-changes with no branch args)
if [ -n "$arg2" ]; then
    base="$arg1"; feature="$arg2"
elif [ -n "$arg1" ]; then
    base="main"; feature="$arg1"
else
    base="main"; feature=""
fi

feature_ref="${feature:-HEAD}"
merge_base=$(git merge-base "$base" "$feature_ref")

if [ -z "$feature" ]; then
    git diff "$merge_base" -- "$path"
else
    git diff "$merge_base" "$feature" -- "$path"
fi
