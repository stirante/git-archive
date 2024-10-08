#!/bin/bash

# git-archive: Archive and restore git branches using tags.
# Usage: git-archive [options] <put|restore> [branch]

# Function to display help
show_help() {
  echo "Usage: git-archive [options] <put|restore> [branch]"
  echo ""
  echo "Commands:"
  echo "  put [branch]     Archive the specified branch. If no branch is specified, archives the current branch."
  echo "  restore <branch> Restore the specified archived branch."
  echo ""
  echo "Options:"
  echo "  -h, --help       Show this help message and exit"
  echo "  -v, --verbose    Enable verbose logging"
}

VERBOSE=false
command=
branch=

# Process options and arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    put)
      command=put
      shift
      break
      ;;
    restore)
      command=restore
      shift
      break
      ;;
    *)
      echo "Error: Unknown option or command '$1'"
      show_help
      exit 1
      ;;
  esac
done

# Check if command is provided
if [ -z "$command" ]; then
  echo "Error: No command provided."
  show_help
  exit 1
fi

# Get the branch name if provided
if [ $# -gt 0 ]; then
  branch="$1"
  shift
fi

# Check for extra arguments
if [ $# -gt 0 ]; then
  echo "Error: Too many arguments."
  show_help
  exit 1
fi

# Determine the default branch dynamically
default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
if [ -z "$default_branch" ]; then
  default_branch="main"
fi
$VERBOSE && echo "Default branch is '$default_branch'"

if [ "$command" = "put" ]; then
  # Use current branch if none specified
  if [ -z "$branch" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)
  fi
  $VERBOSE && echo "Branch to archive is '$branch'"

  # Get the current branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  $VERBOSE && echo "Current branch is '$current_branch'"

  # Check if the branch to archive is the current branch
  if [ "$branch" = "$current_branch" ]; then
    is_current_branch=true
  else
    is_current_branch=false
  fi

  # Cannot archive the default branch
  if [ "$branch" = "$default_branch" ]; then
    echo "Error: Cannot archive the default branch '$default_branch'."
    exit 1
  fi

  $VERBOSE && echo "Archiving branch '$branch'..."

  # Ensure branch exists locally
  if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
    $VERBOSE && echo "Branch '$branch' does not exist locally. Attempting to fetch from remote..."
    git fetch origin "$branch":"$branch"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to fetch branch '$branch' from remote."
      exit 1
    fi
  fi

  # Create a tag
  git tag "archive/$branch" "$branch"
  git push origin "archive/$branch"

  # Switch to default branch if archiving current branch
  if [ "$is_current_branch" = "true" ]; then
    $VERBOSE && echo "Switching to default branch '$default_branch'..."
    git checkout "$default_branch"
  fi

  # Delete the branch locally and remotely
  git branch -D "$branch"
  git push origin --delete "$branch"

  echo "Branch '$branch' has been archived and deleted."

  exit 0

elif [ "$command" = "restore" ]; then
  # Branch must be specified for restore
  if [ -z "$branch" ]; then
    echo "Error: Please specify the branch to restore."
    show_help
    exit 1
  fi

  # Cannot restore the default branch
  if [ "$branch" = "$default_branch" ]; then
    echo "Error: Cannot restore the default branch '$default_branch'."
    exit 1
  fi

  $VERBOSE && echo "Restoring branch '$branch' from tag 'archive/$branch'..."

  # Check if the tag exists
  if ! git rev-parse --verify "refs/tags/archive/$branch" >/dev/null 2>&1; then
    echo "Error: Tag 'archive/$branch' does not exist."
    exit 1
  fi

  # Create a new branch from the tag
  git checkout -b "$branch" "archive/$branch"

  # Push the restored branch to remote
  git push origin "$branch"

  # Delete the tag
  git tag -d "archive/$branch"
  git push origin ":refs/tags/archive/$branch"

  echo "Branch '$branch' has been restored from tag 'archive/$branch'."

  exit 0

else
  echo "Error: Invalid command '$command'."
  show_help
  exit 1
fi
