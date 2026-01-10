#!/bin/bash

# Find all repos with devcontainers in a directory and update them
# Usage: ./find-and-update-all.sh [search-directory]

set -euo pipefail

SEARCH_DIR="${1:-$HOME/projects}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Searching for devcontainers in: ${SEARCH_DIR}${NC}"
echo ""

# Find all devcontainer.json files
DEVCONTAINERS=$(find "$SEARCH_DIR" -type f -path "*/.devcontainer/devcontainer.json" 2>/dev/null || true)

if [ -z "$DEVCONTAINERS" ]; then
    echo -e "${YELLOW}No devcontainers found in ${SEARCH_DIR}${NC}"
    exit 0
fi

# Count them
TOTAL=$(echo "$DEVCONTAINERS" | wc -l)
echo -e "${GREEN}Found ${TOTAL} repos with devcontainers${NC}"
echo ""

# Show list
echo -e "${YELLOW}Repos:${NC}"
echo "$DEVCONTAINERS" | while read -r devcontainer; do
    repo_dir=$(dirname "$(dirname "$devcontainer")")
    repo_name=$(basename "$repo_dir")
    echo "  - $repo_name ($repo_dir)"
done

echo ""
read -p "Update all these repos? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Counters
UPDATED=0
SKIPPED=0
FAILED=0

# Process each devcontainer
echo ""
echo -e "${BLUE}Processing repos...${NC}"
echo ""

echo "$DEVCONTAINERS" | while read -r devcontainer; do
    repo_dir=$(dirname "$(dirname "$devcontainer")")
    repo_name=$(basename "$repo_dir")

    echo -e "${YELLOW}[$(($UPDATED + $SKIPPED + $FAILED + 1))/${TOTAL}] ${repo_name}${NC}"

    # Run update script
    if "${SCRIPT_DIR}/update-single-repo.sh" "$repo_dir" 2>&1 | grep -v "^cd "; then
        # Check if actually updated
        if (cd "$repo_dir" && git diff --quiet .devcontainer/devcontainer.json); then
            ((SKIPPED++)) || true
        else
            # Offer to commit
            read -p "  Commit and push? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                (
                    cd "$repo_dir"
                    git add .devcontainer/devcontainer.json
                    git commit -m "chore: persist Claude authentication in devcontainer

Add Claude config directory mount to avoid re-authentication
when spinning up devcontainers.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
                    git push
                    echo -e "  ${GREEN}✓ Committed and pushed${NC}"
                )
                ((UPDATED++)) || true
            else
                echo -e "  ${YELLOW}⊘ Skipped commit${NC}"
                ((SKIPPED++)) || true
            fi
        fi
    else
        ((FAILED++)) || true
    fi

    echo ""
done

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "Total repos:     ${TOTAL}"
echo -e "${GREEN}Updated:         ${UPDATED}${NC}"
echo -e "${YELLOW}Skipped:         ${SKIPPED}${NC}"
echo -e "${RED}Failed:          ${FAILED}${NC}"
