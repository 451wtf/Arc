#!/bin/bash

# Ask for branch name
read -p "Enter branch name: " branch

# Ask for commit message
read -p "Enter commit message: " message

# Fetch remote branches first
git pull

# Check if branch exists locally
if git show-ref --verify --quiet refs/heads/"$branch"; then
    echo "Switching to existing local branch '$branch'."
    git switch "$branch"
else
    # Check if branch exists on remote
    if git ls-remote --exit-code --heads origin "$branch" >/dev/null; then
        echo "Branch exists on remote. Checking out."
        git switch -c "$branch" origin/"$branch"
    else
        echo "Branch does not exist. Creating locally and on remote."
        git switch -c "$branch"
    fi
fi

# Add all changes
git add .

# Commit with the provided message (skip empty commits)
if ! git diff --cached --quiet; then
    git commit -m "$message" -m "" -m "Pushed using push.sh"
else
    echo "No changes to commit."
fi

# Push to origin (creates branch remotely if it doesn't exist)
git push -u origin "$branch"

# Create a pull request using GitHub CLI (default target: main)
if command -v gh >/dev/null 2>&1; then
    echo "Creating pull request on GitHub..."
    gh pr create --base main --head "$branch" --title "$message" --body "$message\nAuto-created PR from push.sh"
else
    echo "GitHub CLI (gh) not installed. Skipping pull request creation."
fi

# Switch back to main and update
git switch main
git pull
