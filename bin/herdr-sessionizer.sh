#!/usr/bin/env bash

# Directories to pick projects from, e.g. "$HOME/Projects"
search_dir=(
)

if [[ $# -eq 1 ]]; then
    selected=$1
elif [[ ${#search_dir[@]} -eq 0 ]]; then
    echo "No search directories set; edit search_dir in $0" >&2
    exit 1
else
    paths="$(printf "%s\n" "${search_dir[@]}")"$'\n'
    paths+="$(fd --type d -d 3 $(printf " --search-path %s" "${search_dir[@]}"))"
    selected=$(echo "$paths" | fzf --reverse --prompt="Select directory: " --height=16 --scheme=path +m)
fi

if [[ -z "$selected" ]]; then
    exit 0
fi

selected=${selected%/}
child_folder=$(basename "$selected")
parent_folder=$(basename "$(dirname "$selected")")

selected_name=$(echo "$parent_folder~$child_folder" | tr . _)

# Start the herdr server in the background if it isn't running yet
if ! herdr status server 2> /dev/null | grep -q "status: running"; then
    setsid herdr server > /dev/null 2>&1 < /dev/null &
    for _ in {1..50}; do
        herdr status server 2> /dev/null | grep -q "status: running" && break
        sleep 0.1
    done
fi

# Reuse a workspace with the same label, otherwise create one
workspace_id=$(herdr workspace list |
    jq -r --arg name "$selected_name" '.result.workspaces[] | select(.label == $name) | .workspace_id' |
    head -1)

if [[ -z $workspace_id ]]; then
    herdr workspace create --cwd "$selected" --label "$selected_name" --focus > /dev/null
else
    herdr workspace focus "$workspace_id" > /dev/null
fi

if [[ -z $HERDR_ENV ]]; then
    exec herdr
fi
