

all: 
	#!/bin/bash

# Get the path of the main repository
MAIN_REPO=$(pwd)

# Loop over all directories
for dir in */; do
  # Check if the directory contains a .git folder
  if [ -d "$dir/.git" ]; then
    # Add the directory as a submodule
    git submodule add "$MAIN_REPO/$dir" "$dir"
  fi
done

# Update the .gitmodules and index
git submodule update --init --recursive

echo "Submodules have been added successfully."

