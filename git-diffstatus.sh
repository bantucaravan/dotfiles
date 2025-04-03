#!/bin/bash

# Git diffstatus - Categorizes file changes between two commits/branches

# USAGE: git diffstatus <source> <destination>
# Shows three categories of file changes:
# 1. Files modified only in source
# 2. Files modified only in destination
# 3. Files modified in both (with status codes)

# source:  https://claude.ai/chat/5eb3b570-84ad-443e-ae69-0b1a0793ce69

# TODO: 
# - does NOT show files with spaces in the path (addressed?)
# - maybe display diffs directly from source to dest once I know 
#   which diverge in source and dest from base, not the diffs from base 
#   to 1 or 2 (maybe a 3rd status for the both changed, that is the diff source to dest?)
# - think about handling re-namings smartly
# - in a merge does it make sense to simply accept a one sided deletion (and 
#   actually isn't a 2 sided deletion really a no-diff although it appears as one here)

# Special Edge Case: When source modifications (at the char level) are the same as destination 
# modifications, both 
# files differ from merge-base but may not conflict. The destination may contain all 
# source changes plus additional ones. Detecting this efficiently (without performing 
# the actual merge) is challenging, as determining non-conflicting changes requires 
# nearly the same work as performing the merge itself.

gitdiffstatus() {
    local base=$(git merge-base "$1" "$2")
    
    echo "Modified in $1 only:"
    # Get files changed only in $1
    files_in_1=$(comm -23 \
        <(git diff --name-only "$base" "$1" | sort) \
        <(git diff --name-only "$base" "$2" | sort))
    if [ ! -z "$files_in_1" ]; then
        git diff --name-status "$base" "$1" -- $files_in_1
    fi
    
    echo
    echo "Modified in $2 only:"
    # Get files changed only in $2
    files_in_2=$(comm -23 \
        <(git diff --name-only "$base" "$2" | sort) \
        <(git diff --name-only "$base" "$1" | sort))
    if [ ! -z "$files_in_2" ]; then
        git diff --name-status "$base" "$2" -- $files_in_2
    fi
    
    echo
    echo "Modified in both:"
    # Get files changed in both
    files_in_both=$(comm -12 \
        <(git diff --name-only "$base" "$1" | sort) \
        <(git diff --name-only "$base" "$2" | sort))
    if [ ! -z "$files_in_both" ]; then
        while IFS= read -r file; do
            status1=$(git diff --name-status "$base" "$1" -- "$file" | cut -f1)
            status2=$(git diff --name-status "$base" "$2" -- "$file" | cut -f1)
            printf "%-8s -> %-8s %s\n" "$status1" "$status2" "$file"
        done <<< "$files_in_both"
    fi
}

# Execute the function with all arguments passed to the script
gitdiffstatus "$@"
