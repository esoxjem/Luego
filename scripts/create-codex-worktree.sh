#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_worktree="$(git -C "$script_dir/.." rev-parse --show-toplevel)"
source_template="$root_worktree/Luego/Core/Configuration/Secrets.swift.template"

if [ $# -gt 0 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
  echo "Usage: $0 [new-worktree-path] [git-reference]"
  echo "Defaults to the current worktree when no path is provided."
  exit 1
fi

new_worktree="$root_worktree"
git_reference=""

if [ $# -ge 1 ]; then
  new_worktree="$1"
fi

if [ $# -ge 2 ]; then
  git_reference="$2"
fi

if [ ! -d "$new_worktree" ]; then
  if [ -z "$git_reference" ]; then
    echo "Target worktree not found: $new_worktree" >&2
    echo "Pass a git reference as a second argument to create it." >&2
    exit 1
  fi

  git -C "$root_worktree" worktree add "$new_worktree" "$git_reference"
fi

if [ ! -f "$source_template" ]; then
  echo "Missing template: $source_template" >&2
  exit 1
fi

destination_directory="$new_worktree/Luego/Core/Configuration"
destination_file="$destination_directory/Secrets.swift"

mkdir -p "$destination_directory"

if [ -f "$destination_file" ]; then
  echo "Secrets file already exists: $destination_file"
  echo "Copy skipped"
  exit 0
fi

cp "$source_template" "$destination_file"
echo "Copied $source_template to $destination_file"
