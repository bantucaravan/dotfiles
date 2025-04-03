#!/bin/bash
# -------------------------------------------------------------------------
# git_manual_merge.sh
# -------------------
#   This script implements a pre-merge process using Visual Studio Code's
#   three-way merge tool. It lets you manually choose how to merge files that 
#   have been modified in both a destination branch and a source branch BEFORE 
#   performing a git merge.
#   IMPORTANT: If you exit the merge editor with an empty merge result file, 
#   the file will be skipped (retaining the working tree content).
#
# Usage:
#   git manual-merge <destination-branch> <source-branch> [-- <path>...]
# Examples:
#   git manual-merge main feature
#   git manual-merge main feature -- path/to/file.txt
#   git manual-merge main feature -- src/*.js test/*.js
#
# Overview:
#   1. Validates that both destination and source branches exist.
#   2. Determines the common ancestor using 'git merge-base'.
#   3. Identifies files that have diverged from the common ancestor, in destination and source branches.
#   4. If specific paths are provided after '--', filters the diverged files to include only those paths.
#   5. For each diverged file, it:
#        a) Extracts three versions: base (common ancestor), destination, and source.
#        b) Creates an empty result file (required by VS Code's merge tool).
#        c) Launches the VS Code merge tool (code --wait --merge <destination> <source> <base> <result>).
#           The merge editor is opened, and the script waits for you to close this tab 
#           before proceeding to the next file.
#        d) Copies the merge result back into the original file if merge result exist.
#
# Validations, Errors, and Warnings:
#   - If either branch does not exist, the script prints an error and exits.
#   - If no common ancestor is found, an error is printed and the script exits.
#   - If no diverged files are found, a message is printed and the script exits.
#   - After merging, if the result file is empty:
#         * If the original file does NOT exist, nothing is copied (warning shown).
#         * If the original file DOES exist, the file is skipped (original content is retained).
#
# Additional Notes:
#   - Designed for use as a Git alias (e.g., manual-merge in your .gitconfig).
#   - Requires VS Code to be installed and accessible via the 'code' command-line tool.
# -------------------------------------------------------------------------

# FUTURE: insist the tool also run on files that were modified in only one branch of 
# the split from merge base (destination or source only) (or at least files modified in 
# source branch, regardless of modifications in destination branch)

# Source: https://grok.com/share/bGVnYWN5_8be3bbd3-9480-451b-9409-11b30fe8674f

git_premerge_vscode() {
    if [ $# -lt 2 ]; then
        echo "Usage: git premerge-vscode <destination-branch> <source-branch> [-- <path>...]"
        return 1
    fi

    destination_branch="$1"
    source_branch="$2"
    shift 2
    
    # Check for path arguments after "--"
    paths=()
    if [ $# -gt 0 ]; then
        if [ "$1" = "--" ]; then
            shift
            paths=("$@")
        else
            echo "Error: Expected '--' before path arguments"
            echo "Usage: git premerge-vscode <destination-branch> <source-branch> [-- <path>...]"
            return 1
        fi
    fi

    # Ensure branches exist
    if ! git rev-parse --verify "$destination_branch" >/dev/null 2>&1 || \
       ! git rev-parse --verify "$source_branch" >/dev/null 2>&1; then
        echo "Error: One or both branches do not exist."
        return 1
    fi

    # Find the common ancestor
    base_commit=$(git merge-base "$destination_branch" "$source_branch")
    if [ -z "$base_commit" ]; then
        echo "Error: No common ancestor found between $destination_branch and $source_branch."
        return 1
    fi

    # Get list of files that differ from the base in either branch
    files=$(git diff --name-only "$base_commit" "$destination_branch" "$source_branch" | sort -u)
    if [ -z "$files" ]; then
        echo "No files diverged between $destination_branch and $source_branch."
        return 0
    fi
    
    # Filter files by path if specified
    if [ ${#paths[@]} -gt 0 ]; then
        filtered_files=""
        for file in $files; do
            for path in "${paths[@]}"; do
                if [[ "$file" == $path || "$file" == $path/* ]]; then
                    filtered_files="$filtered_files$file"$'\n'
                    break
                fi
            done
        done
        files=$(echo "$filtered_files" | sort -u)
        
        if [ -z "$files" ]; then
            echo "No diverged files match the specified paths."
            return 0
        fi
    fi

    # Temporary directory for file versions
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT  # Clean up on exit

    # Process each file
    for file in $files; do
        echo "Merging: $file"

        # Extract versions
        base_file="$temp_dir/base_$(basename "$file")"
        destination_file="$temp_dir/destination_$(basename "$file")"
        source_file="$temp_dir/source_$(basename "$file")"
        result_file="$temp_dir/result_$(basename "$file")"

        # Get file contents (use /dev/null if file didn't exist)
        git show "$base_commit:$file" > "$base_file" 2>/dev/null || echo -n > "$base_file"
        git show "$destination_branch:$file" > "$destination_file" 2>/dev/null || echo -n > "$destination_file"
        git show "$source_branch:$file" > "$source_file" 2>/dev/null || echo -n > "$source_file"

        # Create empty result file (see discussion below)
        touch "$result_file"

        # Run VS Code merge tool and wait for it to close before proceeding
        code --wait --merge "$destination_file" "$source_file" "$base_file" "$result_file"

        # Only copy if result file has content
        if [ -s "$result_file" ]; then
            cp "$result_file" "$file"
            echo "Updated $file with merge result."
        elif [ ! -f "$file" ]; then
            # If original file doesn't exist and result is empty, do nothing
            echo "Skipped $file (no changes)."
        else
            echo "Skipped $file (kept original content)."
        fi
    done

    echo "Merge complete. Review changes and stage with 'git add' as needed."
}

# Execute the function with all arguments passed to the script
git_premerge_vscode "$@"