#!/bin/bash

# Smart script to update only repos that have devcontainers
# Usage: ./update-repos-with-devcontainers.sh [github-username]

set -euo pipefail

GITHUB_USER="${1:-milesburton}"
CLONE_DIR="${HOME}/devcontainer-updates-$(date +%s)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Finding repos with devcontainers for ${GITHUB_USER}${NC}"
echo ""

# Create working directory
mkdir -p "${CLONE_DIR}"
cd "${CLONE_DIR}"

# Get all repos
echo -e "${YELLOW}Fetching repository list...${NC}"
ALL_REPOS=$(curl -s "https://api.github.com/users/${GITHUB_USER}/repos?per_page=100&type=owner" | \
    jq -r '.[] | "\(.name)|\(.ssh_url)|\(.default_branch)"')

if [ -z "$ALL_REPOS" ]; then
    echo -e "${RED}Failed to fetch repositories${NC}"
    exit 1
fi

TOTAL=$(echo "$ALL_REPOS" | wc -l)
echo "Found ${TOTAL} total repositories"
echo -e "${YELLOW}Checking which ones have devcontainers...${NC}"
echo ""

# Find repos with devcontainers
REPOS_WITH_DEVCONTAINER=""
CHECKED=0

while IFS='|' read -r repo_name ssh_url default_branch; do
    [ -z "$repo_name" ] && continue
    ((CHECKED++))

    # Check if repo has devcontainer using GitHub API
    HAS_DEVCONTAINER=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.github.com/repos/${GITHUB_USER}/${repo_name}/contents/.devcontainer/devcontainer.json")

    if [ "$HAS_DEVCONTAINER" = "200" ]; then
        echo -e "  ${GREEN}✓${NC} ${repo_name}"
        REPOS_WITH_DEVCONTAINER="${REPOS_WITH_DEVCONTAINER}${repo_name}|${ssh_url}|${default_branch}"$'\n'
    else
        echo -e "  ${YELLOW}⊘${NC} ${repo_name} (no devcontainer)"
    fi

    # Rate limiting - be nice to GitHub API
    sleep 0.5
done <<< "$ALL_REPOS"

if [ -z "$REPOS_WITH_DEVCONTAINER" ]; then
    echo ""
    echo -e "${YELLOW}No repositories with devcontainers found${NC}"
    exit 0
fi

# Count repos with devcontainers
DEVCONTAINER_COUNT=$(echo -n "$REPOS_WITH_DEVCONTAINER" | grep -c '^' || echo "0")

echo ""
echo -e "${GREEN}Found ${DEVCONTAINER_COUNT} repos with devcontainers${NC}"
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
PROCESSED=0

echo ""
echo -e "${BLUE}Processing repos...${NC}"
echo ""

# Process each repo
while IFS='|' read -r repo_name ssh_url default_branch; do
    [ -z "$repo_name" ] && continue

    ((PROCESSED++))
    echo -e "${YELLOW}[${PROCESSED}/${DEVCONTAINER_COUNT}] ${repo_name}${NC}"

    # Clone repo
    if ! git clone --depth 1 "$ssh_url" "${repo_name}" 2>/dev/null; then
        echo -e "  ${RED}✗ Failed to clone${NC}"
        ((FAILED++))
        echo ""
        continue
    fi

    cd "${repo_name}"

    # Double-check devcontainer exists (API might be stale)
    if [ ! -f ".devcontainer/devcontainer.json" ]; then
        echo -e "  ${YELLOW}⊘ No devcontainer found (stale API data)${NC}"
        ((SKIPPED++))
        cd ..
        echo ""
        continue
    fi

    # Check if Claude mount already exists
    if grep -q "\.config/claude" .devcontainer/devcontainer.json 2>/dev/null; then
        echo -e "  ${GREEN}✓ Claude mount already configured${NC}"
        ((SKIPPED++))
        cd ..
        echo ""
        continue
    fi

    # Update devcontainer using Python
    echo -e "  ${BLUE}Updating devcontainer...${NC}"

    python3 << 'PYTHON_SCRIPT'
import json
import sys
import re

try:
    with open('.devcontainer/devcontainer.json', 'r') as f:
        content = f.read()

    # Handle JSON with comments
    lines = []
    for line in content.split('\n'):
        if '//' in line:
            code_part = line.split('//')[0]
            if code_part.strip():
                lines.append(code_part.rstrip())
        else:
            lines.append(line)
    clean_content = '\n'.join(lines)
    clean_content = re.sub(r',(\s*[}\]])', r'\1', clean_content)

    config = json.loads(clean_content)

    claude_mount = "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"

    if 'mounts' not in config:
        config['mounts'] = [
            "source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly",
            claude_mount
        ]
    else:
        mounts = config['mounts']
        if isinstance(mounts, list):
            if any('claude' in str(m) for m in mounts):
                sys.exit(1)  # Already has it
            mounts.append(claude_mount)

    with open('.devcontainer/devcontainer.json', 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')

    sys.exit(0)

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT

    UPDATE_RESULT=$?

    if [ $UPDATE_RESULT -eq 0 ]; then
        echo -e "  ${GREEN}✓ Updated devcontainer.json${NC}"

        # Create branch and commit
        BRANCH_NAME="chore/add-claude-auth-mount"
        git checkout -b "${BRANCH_NAME}" 2>/dev/null || git checkout "${BRANCH_NAME}" 2>/dev/null

        git add .devcontainer/devcontainer.json
        git commit -m "chore: persist Claude authentication in devcontainer

Add Claude config directory mount to avoid re-authentication
when spinning up devcontainers.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" >/dev/null 2>&1

        # Push to remote
        if git push -u origin "${BRANCH_NAME}" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Pushed to origin/${BRANCH_NAME}${NC}"
            ((UPDATED++))
        else
            echo -e "  ${RED}✗ Failed to push${NC}"
            ((FAILED++))
        fi
    elif [ $UPDATE_RESULT -eq 1 ]; then
        echo -e "  ${GREEN}✓ Already has Claude mount${NC}"
        ((SKIPPED++))
    else
        echo -e "  ${RED}✗ Failed to update${NC}"
        ((FAILED++))
    fi

    cd ..
    echo ""
done <<< "$REPOS_WITH_DEVCONTAINER"

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "Repos checked:   ${CHECKED}"
echo -e "With devcontainer: ${DEVCONTAINER_COUNT}"
echo -e "Processed:       ${PROCESSED}"
echo -e "${GREEN}Updated:         ${UPDATED}${NC}"
echo -e "${YELLOW}Skipped:         ${SKIPPED}${NC}"
echo -e "${RED}Failed:          ${FAILED}${NC}"
echo ""
echo -e "${YELLOW}Clone directory: ${CLONE_DIR}${NC}"
echo -e "${YELLOW}You can safely delete it when done reviewing${NC}"

if [ "$UPDATED" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "1. Review the pushed branches on GitHub"
    echo -e "2. Create PRs or merge directly: ${BLUE}chore/add-claude-auth-mount${NC}"
fi
