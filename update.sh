#!/bin/sh
# Set the path to the 'dust' directory
DUST_DIR="./dust"

# Loop over all directories in 'dust'
for dir in "$DUST_DIR"/*/; do
  # Check if the directory contains a .git folder
  if [ -d "$dir/.git" ]; then
    # Extract the URL of the remote repository
    REPO_URL=$(git -C "$dir" config --get remote.origin.url)
    
    # Check if REPO_URL is non-empty
    if [ -n "$REPO_URL" ]; then
      # Add the directory as a submodule using the repository URL
      git submodule add "$REPO_URL" "${dir#$DUST_DIR/}"
    else
      echo "No remote URL found for $dir, skipping..."
    fi
  fi
done

# Update the .gitmodules and index
git submodule update --init --recursive

echo "Submodules from '$DUST_DIR' have been added successfully."

