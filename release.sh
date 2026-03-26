#!/bin/bash

# Simple release script for Pigeon
# Usage: ./release.sh [version]

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Pigeon Release Assistant${NC}"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes. Please commit or stash them first.${NC}"
    exit 1
fi

# Fetch latest tags
echo -e "Fetching latest tags from origin..."
git fetch --tags

# Get the latest version tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "Latest version tag: ${GREEN}${LATEST_TAG}${NC}"

# Suggest next version (simple patch bump)
VERSION_PART=$(echo $LATEST_TAG | sed 's/v//')
MAJOR=$(echo $VERSION_PART | cut -d. -f1)
MINOR=$(echo $VERSION_PART | cut -d. -f2)
PATCH=$(echo $VERSION_PART | cut -d. -f3)
NEXT_PATCH=$((PATCH + 1))
SUGGESTED_VERSION="v${MAJOR}.${MINOR}.${NEXT_PATCH}"

# Get new version from user
if [ -z "$1" ]; then
    read -p "Enter new version tag (default: $SUGGESTED_VERSION): " NEW_TAG
    NEW_TAG=${NEW_TAG:-$SUGGESTED_VERSION}
else
    NEW_TAG=$1
fi

# Ensure version starts with 'v'
if [[ ! $NEW_TAG == v* ]]; then
    NEW_TAG="v$NEW_TAG"
fi

echo -e "Releasing version: ${GREEN}${NEW_TAG}${NC}"

# Confirm
read -p "Are you sure you want to tag and push ${NEW_TAG}? (y/n): " CONFIRM
if [[ $CONFIRM != [yY] ]]; then
    echo "Release cancelled."
    exit 0
fi

# Create tag
echo -e "Creating tag ${NEW_TAG}..."
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"

# Push tag
echo -e "Pushing tag ${NEW_TAG} to origin..."
git push origin "$NEW_TAG"

echo -e "${GREEN}Success! Release ${NEW_TAG} has been pushed.${NC}"
echo -e "GitHub Actions will now build and publish the release."
