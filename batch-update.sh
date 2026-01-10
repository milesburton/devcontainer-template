#!/bin/bash

# Batch update script - clones repos and updates those with devcontainers
# Usage: ./batch-update.sh github-username "repo1 repo2 repo3..."
# Or: ./batch-update.sh github-username  (updates ALL repos)

GITHUB_USER="${1}"
SPECIFIC_REPOS="${2}"  # Optional: space-separated list of repos

if [ -z "$GITHUB_USER" ]; then
    echo "Usage: $0 github-username [\"repo1 repo2 repo3\"]"
    exit 1
fi

CLONE_DIR="${HOME}/devcontainer-updates-$(date +%s)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Batch updating devcontainers for ${GITHUB_USER}${NC}"
echo ""

mkdir -p "${CLONE_DIR}"
cd "${CLONE_DIR}"

# Get list of repos to process
if [ -n "$SPECIFIC_REPOS" ]; then
    echo -e "${YELLOW}Processing specific repos: ${SPECIFIC_REPOS}${NC}"
    REPOS=""
    for repo in $SPECIFIC_REPOS; do
        REPOS="${REPOS}${repo}|git@github.com:${GITHUB_USER}/${repo}.git"$'\n'
    done
else
    echo -e "${YELLOW}Fetching all repos...${NC}"
    REPOS=$(curl -s "https://api.github.com/users/${GITHUB_USER}/repos?per_page=100&type=owner" | \
        jq -r '.[] | "\(.name)|\(.ssh_url)"' 2>/dev/null)

    if [ -z "$REPOS" ]; then
        echo -e "${RED}Failed to fetch repositories${NC}"
        exit 1
    fi
fi

TOTAL=$(echo -n "$REPOS" | grep -c '|' || echo "0")
echo -e "Processing ${TOTAL} repos"
echo ""

# Counters
UPDATED=0
SKIPPED=0
FAILED=0
NO_DEVCONTAINER=0

# Process each repo
PROCESSED=0
while IFS='|' read -r repo_name ssh_url; do
    [ -z "$repo_name" ] && continue

    ((PROCESSED++))
    echo -e "${YELLOW}[${PROCESSED}/${TOTAL}] ${repo_name}${NC}"

    # Clone
    if ! git clone --depth 1 --quiet "$ssh_url" "${repo_name}" 2>/dev/null; then
        echo -e "  ${RED}✗ Failed to clone${NC}"
        ((FAILED++))
        echo ""
        continue
    fi

    cd "${repo_name}"

    # Check for devcontainer
    if [ ! -f ".devcontainer/devcontainer.json" ]; then
        echo -e "  ⊘ No devcontainer"
        ((NO_DEVCONTAINER++))
        cd ..
        echo ""
        continue
    fi

    # Check if already has Claude mount
    if grep -q "\.config/claude" .devcontainer/devcontainer.json 2>/dev/null; then
        echo -e "  ${GREEN}✓ Already configured${NC}"
        ((SKIPPED++))
        cd ..
        echo ""
        continue
    fi

    # Update
    python3 << 'EOF'
import json, sys, re
try:
    with open('.devcontainer/devcontainer.json', 'r') as f:
        content = f.read()
    lines = [line.split('//')[0].rstrip() if '//' in line and line.split('//')[0].strip() else line
             for line in content.split('\n')]
    clean = re.sub(r',(\s*[}\]])', r'\1', '\n'.join(lines))
    config = json.loads(clean)

    mount = "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"

    if 'mounts' not in config:
        config['mounts'] = ["source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly", mount]
    else:
        if isinstance(config['mounts'], list) and not any('claude' in str(m) for m in config['mounts']):
            config['mounts'].append(mount)
        else:
            sys.exit(1)

    with open('.devcontainer/devcontainer.json', 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(2)
EOF

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Updated${NC}"

        # Commit and push
        git checkout -b chore/add-claude-auth-mount 2>/dev/null
        git add .devcontainer/devcontainer.json
        git commit -q -m "chore: persist Claude authentication in devcontainer

Add Claude config directory mount to avoid re-authentication
when spinning up devcontainers.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

        if git push -q -u origin chore/add-claude-auth-mount 2>/dev/null; then
            echo -e "  ${GREEN}✓ Pushed${NC}"
            ((UPDATED++))
        else
            echo -e "  ${YELLOW}⊘ Couldn't push (may already exist)${NC}"
            ((SKIPPED++))
        fi
    else
        echo -e "  ${RED}✗ Update failed${NC}"
        ((FAILED++))
    fi

    cd ..
    echo ""
done <<< "$REPOS"

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "Total repos:       ${TOTAL}"
echo -e "No devcontainer:   ${NO_DEVCONTAINER}"
echo -e "${GREEN}Updated & pushed:  ${UPDATED}${NC}"
echo -e "${YELLOW}Skipped:           ${SKIPPED}${NC}"
echo -e "${RED}Failed:            ${FAILED}${NC}"
echo ""
echo -e "${BLUE}Working directory: ${CLONE_DIR}${NC}"
echo ""

if [ "$UPDATED" -gt 0 ]; then
    echo -e "${GREEN}Success! ${UPDATED} repos updated.${NC}"
    echo -e "Branch: ${BLUE}chore/add-claude-auth-mount${NC}"
    echo -e "You can now create PRs or merge these branches."
fi
