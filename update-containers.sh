#!/bin/bash

sudo apt update && sudo apt upgrade -y

for dir in */; do
    # Remove trailing slash for cleaner output
    dir_name="${dir%/}"
    
    # Check if docker-compose.yml exists before proceeding
    if [[ ! -f "$dir/docker-compose.yml" && ! -f "$dir/docker-compose.yaml" && ! -f "$dir/compose.yml" && ! -f "$dir/compose.yaml" ]]; then
        echo "Skipping $dir_name: No compose file found"
        continue
    fi
    
    echo "Processing: $dir_name"
    
    # Use pushd/popd instead of cd to avoid having to track directory changes
    if ! pushd "$dir" > /dev/null 2>&1; then
        echo "Error: Cannot enter directory $dir_name"
        continue
    fi
    
    # Pull images (continue even if some fail)
    if ! docker compose pull --quiet; then
        echo "Warning: Pull failed for $dir_name, but continuing..."
    fi
    
    # Update the stack
    if ! docker compose up -d --remove-orphans; then
        echo "Error: Failed to update stack in $dir_name"
        popd > /dev/null
        continue
    fi
    
    popd > /dev/null
    echo "✓ Completed: $dir_name"
    echo ""
done

echo ""
echo "Cleaning up unused Docker resources..."
docker system prune -f
