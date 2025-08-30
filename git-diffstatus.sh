#!/bin/bash

# Git diffstatus - Categorizes file changes between two commits/branches

# USAGE: git diffstatus <source> <destination> [--debug]
# Shows three categories of file changes:
# 1. Files modified only in source
# 2. Files modified only in destination
# 3. Files modified in both (with status codes)

# source:  https://claude.ai/chat/5eb3b570-84ad-443e-ae69-0b1a0793ce69

#  BUG: Cannot handle files with spaces in the path. such cases are cut onto separate lines.
# Here is a dummy example:
# Bug behavior:
# ```
# Modified in source-branch only:
# R(old)  app/backend/lib/prompts/resume_parsing/xml/openai-o1/0.0.4-sample_output/Noah
# R(new)  Chasek-Macfoy_0.0.4.xml
# R(old)  app/backend/lib/prompts/resume_parsing/xml/openai-o1/0.0.5-sample_output/Noah
# R(new)  Chasek-Macfoy_0.0.5.xml
# ```
# The  true old renamed path is "app/backend/lib/prompts/resume_parsing/xml/openai-o1/0.0.4-sample_output/Noah Chasek-Macfoy_0.0.4.xml" 
# The desired behavior is:
# ```
# Modified in source-branch only:
# R(old)  app/backend/lib/prompts/resume_parsing/xml/openai-o1/0.0.4-sample_output/Noah Chasek-Macfoy_0.0.4.xml
# R(new)  app/backend/lib/prompts/resume_parsing/xml/openai-o1/0.0.5-sample_output/Noah  Chasek-Macfoy_0.0.5.xml
# ```
# Or maybe with quotation marks or escapes for the spaces if that makes the implementation easier.

# BUG: in cases where a file is deleted or added on one side only, the file is shown under "modified in both"\
# and erroneously labeled as the opposite action (created or deleted) on the other side. desired behavior is if a file \
# is created or deleted on one side only, then it listed as modified only on the side it was created/deleted in.

# BUG: if there are multiple renamed files it is unclear which R(old) matches to 
# which R(new), however they follow one line after the other so it isn't actually that hard to know


# - maybe display diffs directly from source to dest once I know 
#   which diverge in source and dest from base, not the diffs from base 
#   to 1 or 2 (maybe a 3rd status for the both changed, that is the diff source to dest?)


# Special Edge Case: When source modifications (at the char level) are the same as destination 
# modifications, both 
# files differ from merge-base but may not conflict. The destination may contain all 
# source changes plus additional ones. Detecting this efficiently (without performing 
# the actual merge) is challenging, as determining non-conflicting changes requires 

gitdiffstatus() {
    # Check if debug mode is enabled
    local debug_mode=false
    if [[ "$3" == "--debug" ]]; then
        debug_mode=true
    fi
    
    if [ $# -lt 2 ]; then
        echo "Usage: git diffstatus <source> <destination> [--debug]"
        return 1
    fi

    # Set the debug log to the current directory
    local debug_log=".git-diffstatus-debug.log"
    
    # Initialize or clear debug log if in debug mode
    if $debug_mode; then
        echo "Debug mode enabled, logging to $debug_log" > "$debug_log"
    fi

    local base=$(git --no-pager merge-base "$1" "$2" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Could not find merge base between $1 and $2"
        return 1
    fi
    
    # Get all changes with status and path for both branches
    # Using -M to detect renames with a similarity threshold of 50%
    local changes1=$(git --no-pager diff -M50 --name-status "$base" "$1")
    local changes2=$(git --no-pager diff -M50 --name-status "$base" "$2")
    
    # Get direct diff between branches to detect files that exist in one branch but not the other
    local direct_diff=$(git --no-pager diff -M50 --name-status "$1" "$2")
    
    # Debug logging function to avoid repetition
    debug_log() {
        if $debug_mode; then
            echo "$1" >> "$debug_log"
        fi
    }
    
    # Debug outputs for common.txt
    debug_log "DEBUG: changes in $1 from base:"
    if $debug_mode; then
        echo "$changes1" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: changes in $2 from base:"
    if $debug_mode; then
        echo "$changes2" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: direct diff from $1 to $2:"
    if $debug_mode; then
        echo "$direct_diff" | grep common >> "$debug_log"
    fi
    
    # Process renamed files and store them separately
    local renamed_in_1=""
    local renamed_in_2=""
    
    # Extract renamed files from branch 1
    while IFS= read -r line; do
        if [[ "$line" =~ ^R[0-9]*[[:space:]]+(.*)[[:space:]]+(.*) ]]; then
            local old_path="${BASH_REMATCH[1]}"
            local new_path="${BASH_REMATCH[2]}"
            renamed_in_1+="$old_path:$new_path"$'\n'
        fi
    done <<< "$changes1"
    
    # Extract renamed files from branch 2
    while IFS= read -r line; do
        if [[ "$line" =~ ^R[0-9]*[[:space:]]+(.*)[[:space:]]+(.*) ]]; then
            local old_path="${BASH_REMATCH[1]}"
            local new_path="${BASH_REMATCH[2]}"
            renamed_in_2+="$old_path:$new_path"$'\n'
        fi
    done <<< "$changes2"
    
    # Get all file paths affected in each branch
    # For non-renamed files, we store the path
    # For renamed files, we store both old and new paths
    local all_paths1=""
    local all_paths2=""
    
    # Get deleted files in each branch
    local deleted_in_1=""
    local deleted_in_2=""
    
    # Get added files in each branch
    local added_in_1=""
    local added_in_2=""
    
    # Process all changes for branch 1
    while IFS= read -r line; do
        if [[ "$line" =~ ^R[0-9]*[[:space:]]+(.*)[[:space:]]+(.*) ]]; then
            # For renames, add both old and new paths
            all_paths1+="${BASH_REMATCH[1]}"$'\n'
            all_paths1+="${BASH_REMATCH[2]}"$'\n'
        elif [[ "$line" =~ ^[A-Z][[:space:]]+(.+) ]]; then
            # For other changes, add the file path
            all_paths1+="${BASH_REMATCH[1]}"$'\n'
            
            # Track deleted files
            if [[ "$line" =~ ^D[[:space:]]+(.+) ]]; then
                deleted_in_1+="${BASH_REMATCH[1]}"$'\n'
                
                # Debug for common.txt
                if [[ "${BASH_REMATCH[1]}" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is deleted in $1"
                fi
            fi
            
            # Track added files
            if [[ "$line" =~ ^A[[:space:]]+(.+) ]]; then
                added_in_1+="${BASH_REMATCH[1]}"$'\n'
                
                # Debug for common.txt
                if [[ "${BASH_REMATCH[1]}" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is added in $1"
                fi
            fi
        fi
    done <<< "$changes1"
    
    # Process all changes for branch 2
    while IFS= read -r line; do
        if [[ "$line" =~ ^R[0-9]*[[:space:]]+(.*)[[:space:]]+(.*) ]]; then
            # For renames, add both old and new paths
            all_paths2+="${BASH_REMATCH[1]}"$'\n'
            all_paths2+="${BASH_REMATCH[2]}"$'\n'
        elif [[ "$line" =~ ^[A-Z][[:space:]]+(.+) ]]; then
            # For other changes, add the file path
            all_paths2+="${BASH_REMATCH[1]}"$'\n'
            
            # Track deleted files
            if [[ "$line" =~ ^D[[:space:]]+(.+) ]]; then
                deleted_in_2+="${BASH_REMATCH[1]}"$'\n'
                
                # Debug for common.txt
                if [[ "${BASH_REMATCH[1]}" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is deleted in $2"
                fi
            fi
            
            # Track added files
            if [[ "$line" =~ ^A[[:space:]]+(.+) ]]; then
                added_in_2+="${BASH_REMATCH[1]}"$'\n'
                
                # Debug for common.txt
                if [[ "${BASH_REMATCH[1]}" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is added in $2"
                fi
            fi
        fi
    done <<< "$changes2"
    
    # Sort the paths for comparison (removing duplicate entries and empty lines)
    local sorted_paths1=$(echo "$all_paths1" | grep -v "^$" | sort -u)
    local sorted_paths2=$(echo "$all_paths2" | grep -v "^$" | sort -u)
    local sorted_added_in_1=$(echo "$added_in_1" | grep -v "^$" | sort -u)
    local sorted_added_in_2=$(echo "$added_in_2" | grep -v "^$" | sort -u)
    
    # Build lists of files that should only appear in the "Modified in both" section
    local files_for_both=""
    
    # Identify files that exist in one branch but not the other (by direct diff)
    while IFS= read -r line; do
        if [[ "$line" =~ ^A[[:space:]]+(.+) ]]; then
            # File exists in branch 2 but not in branch 1
            local file="${BASH_REMATCH[1]}"
            # Check if it's a file added in branch 2
            if echo "$sorted_added_in_2" | grep -q "^${file}$"; then
                files_for_both+="$file"$'\n'
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt added to files_for_both from branch 2"
                fi
            fi
        elif [[ "$line" =~ ^D[[:space:]]+(.+) ]]; then
            # File exists in branch 1 but not in branch 2
            local file="${BASH_REMATCH[1]}"
            # Check if it's a file added in branch 1
            if echo "$sorted_added_in_1" | grep -q "^${file}$"; then
                files_for_both+="$file"$'\n'
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt added to files_for_both from branch 1"
                fi
            fi
        fi
    done <<< "$direct_diff"
    
    # Sort the list of files for both sections
    local sorted_files_for_both=$(echo "$files_for_both" | grep -v "^$" | sort -u)
    
    # Debug output
    debug_log "DEBUG: all paths in $1:"
    if $debug_mode; then
        echo "$sorted_paths1" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: all paths in $2:"
    if $debug_mode; then
        echo "$sorted_paths2" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: all added in $1:"
    if $debug_mode; then
        echo "$sorted_added_in_1" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: all added in $2:"
    if $debug_mode; then
        echo "$sorted_added_in_2" | grep common >> "$debug_log"
    fi
    debug_log "DEBUG: files for both sections:"
    if $debug_mode; then
        echo "$sorted_files_for_both" | grep common >> "$debug_log"
    fi
    
    echo "Modified in $1 only:"
    local found_in_1_only=false
    
    # Files changed only in branch 1
    while IFS= read -r file; do
        # Skip empty lines
        [[ -z "$file" ]] && continue
        
        # Skip if the file is also in branch 2's changes
        if echo "$sorted_paths2" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt is in both branches, skipping from $1 only"
            fi
            continue
        fi
        
        # Skip files that should be in the "Modified in both" section
        if echo "$sorted_files_for_both" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt will be in 'Modified in both', skipping from $1 only"
            fi
            continue
        fi
        
        found_in_1_only=true
        
        # Check if this is a renamed file (new path)
        local is_renamed=false
        local old_path=""
        
        for renamed in $(echo "$renamed_in_1" | grep -v '^$'); do
            IFS=':' read -r old_path_r new_path_r <<< "$renamed"
            if [[ "$new_path_r" == "$file" ]]; then
                is_renamed=true
                old_path="$old_path_r"
                break
            fi
        done
        
        if [[ "$is_renamed" == "true" ]]; then
            # This is a renamed file
            echo "R(old)  $old_path"
            echo "R(new)  $file"
        else
            # Regular change - use printf for deleted files to ensure consistent formatting
            local status_line=$(grep -E "^[A-Z][[:space:]]+$file$" <<< "$changes1")
            if [[ -n "$status_line" ]]; then
                echo "$status_line"
            elif echo "$deleted_in_1" | grep -q "^${file}$"; then
                # Explicitly handle deleted files that might have been filtered out
                printf "D       %s\n" "$file"
            fi
        fi
    done <<< "$sorted_paths1"
    
    if [[ "$found_in_1_only" == "false" ]]; then
        echo "(none)"
    fi
    
    echo
    echo "Modified in $2 only:"
    local found_in_2_only=false
    
    # Files changed only in branch 2
    while IFS= read -r file; do
        # Skip empty lines
        [[ -z "$file" ]] && continue
        
        # Skip if the file is also in branch 1's changes
        if echo "$sorted_paths1" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt is in both branches, skipping from $2 only"
            fi
            continue
        fi
        
        # Skip files that should be in the "Modified in both" section
        if echo "$sorted_files_for_both" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt will be in 'Modified in both', skipping from $2 only"
            fi
            continue
        fi
        
        found_in_2_only=true
        
        # Check if this is a renamed file (new path)
        local is_renamed=false
        local old_path=""
        
        for renamed in $(echo "$renamed_in_2" | grep -v '^$'); do
            IFS=':' read -r old_path_r new_path_r <<< "$renamed"
            if [[ "$new_path_r" == "$file" ]]; then
                is_renamed=true
                old_path="$old_path_r"
                break
            fi
        done
        
        if [[ "$is_renamed" == "true" ]]; then
            # This is a renamed file
            echo "R(old)  $old_path"
            echo "R(new)  $file"
        else
            # Regular change
            grep -E "^[A-Z][[:space:]]+$file$" <<< "$changes2"
        fi
    done <<< "$sorted_paths2"
    
    if [[ "$found_in_2_only" == "false" ]]; then
        echo "(none)"
    fi
    
    echo
    echo "Modified in both:"
    local found_in_both=false
    
    # Create a combined list of paths to check
    local all_combined_paths=$(echo -e "$sorted_paths1\n$sorted_paths2" | sort -u)
    debug_log "DEBUG: all combined paths:"
    if $debug_mode; then
        echo "$all_combined_paths" | grep common >> "$debug_log"
    fi
    
    # First handle files present in both branches
    while IFS= read -r file; do
        # Skip empty lines
        [[ -z "$file" ]] && continue
        
        # Debug for common.txt
        if [[ "$file" == "common.txt" ]]; then
            debug_log "DEBUG: Processing common.txt in 'Modified in both' section"
        fi
        
        # Determine status in branch 1
        local status1=""
        local is_renamed1=false
        local old_path1=""
        
        # Check if this path appears in branch 1
        if ! echo "$sorted_paths1" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt not found in $1 paths"
            fi
            continue  # Skip if this file doesn't appear in branch 1's changes
        fi
        
        # Check if this path appears in branch 2
        if ! echo "$sorted_paths2" | grep -q "^${file}$"; then
            # Debug for common.txt
            if [[ "$file" == "common.txt" ]]; then
                debug_log "DEBUG: common.txt not found in $2 paths"
            fi
            continue  # Skip if this file doesn't appear in branch 2's changes
        fi
        
        # Debug for common.txt
        if [[ "$file" == "common.txt" ]]; then
            debug_log "DEBUG: common.txt is in both branches' paths"
        fi
        
        # Check if it's a renamed file in branch 1
        for renamed in $(echo "$renamed_in_1" | grep -v '^$'); do
            IFS=':' read -r old_path_r new_path_r <<< "$renamed"
            if [[ "$new_path_r" == "$file" ]]; then
                is_renamed1=true
                status1="R"
                old_path1="$old_path_r"
                break
            elif [[ "$old_path_r" == "$file" && "$new_path_r" != "$file" ]]; then
                # If this is an old path in a rename and not the same as new path (edge case),
                # skip it as we'll handle it with the new path
                continue 2
            fi
        done
        
        # If not renamed, get the regular status
        if [[ "$is_renamed1" == "false" ]]; then
            status1=$(grep -E "^[A-Z][[:space:]]+$file$" <<< "$changes1" | awk '{print $1}')
            # If no status found (could be deleted or part of a rename)
            if [[ -z "$status1" ]]; then
                if echo "$deleted_in_1" | grep -q "^${file}$"; then
                    status1="D"
                    # Debug for common.txt
                    if [[ "$file" == "common.txt" ]]; then
                        debug_log "DEBUG: Setting common.txt status in $1 to D"
                    fi
                fi
            fi
        fi
        
        # Determine status in branch 2
        local status2=""
        local is_renamed2=false
        local old_path2=""
        
        # Check if it's a renamed file in branch 2
        for renamed in $(echo "$renamed_in_2" | grep -v '^$'); do
            IFS=':' read -r old_path_r new_path_r <<< "$renamed"
            if [[ "$new_path_r" == "$file" ]]; then
                is_renamed2=true
                status2="R"
                old_path2="$old_path_r"
                break
            elif [[ "$old_path_r" == "$file" && "$new_path_r" != "$file" ]]; then
                # If this is an old path in a rename and not the same as new path (edge case),
                # skip it as we'll handle it with the new path
                continue 2
            fi
        done
        
        # If not renamed, get the regular status
        if [[ "$is_renamed2" == "false" ]]; then
            status2=$(grep -E "^[A-Z][[:space:]]+$file$" <<< "$changes2" | awk '{print $1}')
            # If no status found (could be deleted or part of a rename)
            if [[ -z "$status2" ]]; then
                if echo "$deleted_in_2" | grep -q "^${file}$"; then
                    status2="D"
                    # Debug for common.txt
                    if [[ "$file" == "common.txt" ]]; then
                        debug_log "DEBUG: Setting common.txt status in $2 to D"
                    fi
                fi
            fi
        fi
        
        # Debug statuses for common.txt
        if [[ "$file" == "common.txt" ]]; then
            debug_log "DEBUG: common.txt status1=$status1, status2=$status2"
        fi
        
        # Only output if we have a status for both branches
        if [[ -n "$status1" && -n "$status2" ]]; then
            found_in_both=true
            
            # Format the output depending on the cases
            if [[ "$is_renamed1" == "true" && "$is_renamed2" == "true" ]]; then
                # Both sides renamed
                printf "%-8s -> %-8s %s (was %s in $1, %s in $2)\n" "R" "R" "$file" "$old_path1" "$old_path2"
            elif [[ "$is_renamed1" == "true" ]]; then
                # Only renamed in branch 1
                if [[ "$status2" == "D" ]]; then
                    printf "%-8s -> %-8s %s (was %s in $1)\n" "R" "D" "$file" "$old_path1"
                else
                    printf "%-8s -> %-8s %s (was %s in $1)\n" "R" "$status2" "$file" "$old_path1"
                fi
            elif [[ "$is_renamed2" == "true" ]]; then
                # Only renamed in branch 2
                if [[ "$status1" == "D" ]]; then
                    printf "%-8s -> %-8s %s (was %s in $2)\n" "D" "R" "$file" "$old_path2"
                else
                    printf "%-8s -> %-8s %s (was %s in $2)\n" "$status1" "R" "$file" "$old_path2"
                fi
            else
                # Regular change in both branches or deleted in one
                printf "%-8s -> %-8s %s\n" "$status1" "$status2" "$file"
            fi
        fi
    done <<< "$all_combined_paths"
    
    # Special handling for files that are not found in the common paths but are deleted in one branch
    # and modified in another
    
    # Files deleted in branch 2 but modified in branch 1
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Debug for common.txt
        if [[ "$file" == "common.txt" ]]; then
            debug_log "DEBUG: Checking if common.txt is deleted in $2 but modified in $1"
        fi
        
        # Only process if this is a deletion in branch 2 and file doesn't appear in both lists already
        if echo "$deleted_in_2" | grep -q "^${file}$"; then
            # Check if we already processed this file
            if ! echo "$all_combined_paths" | grep -q "^${file}$"; then
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is deleted in $2 and not in combined paths"
                fi
                
                # Check if modified in branch 1
                local status1=$(grep -E "^[AM][[:space:]]+$file$" <<< "$changes1" | awk '{print $1}')
                if [[ -n "$status1" ]]; then
                    found_in_both=true
                    printf "%-8s -> %-8s %s\n" "$status1" "D" "$file" 
                    # Debug for common.txt
                    if [[ "$file" == "common.txt" ]]; then
                        debug_log "DEBUG: common.txt is modified in $1 with status $status1"
                    fi
                fi
            fi
        fi
    done <<< "$sorted_paths1"
    
    # Files deleted in branch 1 but modified in branch 2
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Debug for common.txt
        if [[ "$file" == "common.txt" ]]; then
            debug_log "DEBUG: Checking if common.txt is deleted in $1 but modified in $2"
        fi
        
        # Only process if this is a deletion in branch 1 and file doesn't appear in both lists already
        if echo "$deleted_in_1" | grep -q "^${file}$"; then
            # Check if we already processed this file
            if ! echo "$all_combined_paths" | grep -q "^${file}$"; then
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt is deleted in $1 and not in combined paths"
                fi
                
                # Check if modified in branch 2
                local status2=$(grep -E "^[AM][[:space:]]+$file$" <<< "$changes2" | awk '{print $1}')
                if [[ -n "$status2" ]]; then
                    found_in_both=true
                    printf "%-8s -> %-8s %s\n" "D" "$status2" "$file" 
                    # Debug for common.txt
                    if [[ "$file" == "common.txt" ]]; then
                        debug_log "DEBUG: common.txt is modified in $2 with status $status2"
                    fi
                fi
            fi
        fi
    done <<< "$sorted_paths2"
    
    # Special handling for files added in one branch but not present in the other
    while IFS= read -r line; do
        if [[ "$line" =~ ^A[[:space:]]+(.+) ]]; then
            # File exists in branch 2 but not in branch 1
            local file="${BASH_REMATCH[1]}"
            
            # Check if it's a file added in branch 2
            if echo "$sorted_added_in_2" | grep -q "^${file}$"; then
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt exists in $2 only, marking as A in $2 and implicit D in $1"
                fi
                
                found_in_both=true
                printf "%-8s -> %-8s %s\n" "D" "A" "$file"
            fi
        elif [[ "$line" =~ ^D[[:space:]]+(.+) ]]; then
            # File exists in branch 1 but not in branch 2
            local file="${BASH_REMATCH[1]}"
            
            # Check if it's a file added in branch 1
            if echo "$sorted_added_in_1" | grep -q "^${file}$"; then
                # Debug for common.txt
                if [[ "$file" == "common.txt" ]]; then
                    debug_log "DEBUG: common.txt exists in $1 only, marking as A in $1 and implicit D in $2"
                fi
                
                found_in_both=true
                printf "%-8s -> %-8s %s\n" "A" "D" "$file"
            fi
        fi
    done <<< "$direct_diff"
    
    if [[ "$found_in_both" == "false" ]]; then
        echo "(none)"
    fi
}

# Execute the function with all arguments passed to the script
gitdiffstatus "$@" 