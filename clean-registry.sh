#!/bin/bash

REGISTRY="localhost:5000"  # Change this if your registry is hosted elsewhere

# Step 1: List all repositories
repos=$(curl -s -X GET "http://$REGISTRY/v2/_catalog" | jq -r '.repositories[]')

for repo in $repos; do
    echo "Processing repository: $repo"

    # Step 2: List all tags for the repository
    tags=$(curl -s -X GET "http://$REGISTRY/v2/$repo/tags/list" | jq -r '.tags[]')

    for tag in $tags; do
        if [ "$tag" != "latest" ]; then
            echo "  Deleting tag: $tag"

            # Step 3: Get the digest for the tag
            digest=$(curl -s -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "http://$REGISTRY/v2/$repo/manifests/$tag" | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')

            if [ -n "$digest" ]; then
                # Step 4: Delete the manifest
                curl -s -X DELETE "http://$REGISTRY/v2/$repo/manifests/$digest"
                echo "    Deleted manifest for $repo:$tag"
            else
                echo "    Failed to get digest for $repo:$tag"
            fi
        else
            echo "  Keeping tag: latest"
        fi
    done
done

# Step 5: Run garbage collection using Podman
echo "Running garbage collection..."
podman stop registry
podman run --rm --entrypoint /bin/registry docker.io/library/registry:2 garbage-collect /etc/docker/registry/config.yml
podman start registry

echo "Cleanup complete."