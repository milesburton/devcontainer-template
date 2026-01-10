#!/bin/bash

# Script to update all GitHub repos with Claude auth mount in devcontainers
# Usage: ./update-all-devcontainers.sh [github-username] [max-repos]
# Example: ./update-all-devcontainers.sh milesburton 5  # Test with 5 repos

set -euo pipefail

GITHUB_USER="${1:-milesburton}"
MAX_REPOS="${2:-999}"  # Default to all repos
CLONE_DIR="${HOME}/devcontainer-bulk-update-$(date +%s)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting devcontainer update process for ${GITHUB_USER}${NC}"
echo "Clone directory: ${CLONE_DIR}"

# Create temporary working directory
mkdir -p "${CLONE_DIR}"
cd "${CLONE_DIR}"

# Fetch all repos using proper JSON parsing
echo -e "\n${YELLOW}Fetching repository list...${NC}"
REPOS_JSON=$(curl -s "https://api.github.com/users/${GITHUB_USER}/repos?per_page=100&type=owner")

# Parse JSON to get name and ssh_url
REPOS=$(echo "$REPOS_JSON" | python3 -c "
import json, sys
try:
    repos = json.load(sys.stdin)
    for repo in repos:
        if 'name' in repo and 'ssh_url' in repo:
            print(f\"{repo['name']}|{repo['ssh_url']}\")
except:
    pass
")

if [ -z "$REPOS" ]; then
    echo -e "${RED}Failed to fetch repositories${NC}"
    exit 1
fi

# Count total repos
TOTAL_REPOS=$(echo "$REPOS" | wc -l)
echo "Found ${TOTAL_REPOS} repositories"

# Apply limit if set
if [ "$MAX_REPOS" -lt "$TOTAL_REPOS" ]; then
    echo -e "${YELLOW}Limiting to first ${MAX_REPOS} repos for testing${NC}"
    REPOS=$(echo "$REPOS" | head -n "$MAX_REPOS")
fi

# Counters
UPDATED=0
SKIPPED=0
FAILED=0
PROCESSED=0

# Process each repo
while IFS='|' read -r repo_name repo_url; do
    [ -z "$repo_name" ] && continue

    ((PROCESSED++))
    echo -e "\n${YELLOW}[${PROCESSED}] Processing: ${repo_name}${NC}"

    # Clone repo
    if ! git clone --depth 1 "$repo_url" "${repo_name}" 2>/dev/null; then
        echo -e "${RED}  ✗ Failed to clone${NC}"
        ((FAILED++))
        continue
    fi

    cd "${repo_name}"

    # Check if devcontainer exists
    if [ ! -f ".devcontainer/devcontainer.json" ]; then
        echo -e "  ⊘ No devcontainer found, skipping"
        ((SKIPPED++))
        cd ..
        continue
    fi

    echo -e "  ${GREEN}✓ Devcontainer found${NC}"

    # Check if Claude mount already exists
    if grep -q "\.config/claude" .devcontainer/devcontainer.json 2>/dev/null; then
        echo -e "  ⊘ Claude mount already configured, skipping"
        ((SKIPPED++))
        cd ..
        continue
    fi

    # Backup original
    cp .devcontainer/devcontainer.json .devcontainer/devcontainer.json.backup

    # Update using Python for reliable JSON manipulation
    python3 << 'PYTHON_SCRIPT'
import json
import sys

try:
    with open('.devcontainer/devcontainer.json', 'r') as f:
        content = f.read()
        # Handle JSON with comments (common in devcontainer.json)
        # Simple approach: remove // comments
        lines = []
        for line in content.split('\n'):
            # Remove single-line comments
            if '//' in line:
                code_part = line.split('//')[0]
                if code_part.strip():
                    lines.append(code_part.rstrip())
            else:
                lines.append(line)
        clean_content = '\n'.join(lines)
        config = json.loads(clean_content)

    claude_mount = "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"

    if 'mounts' not in config:
        # No mounts, create array with SSH and Claude
        config['mounts'] = [
            "source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly",
            claude_mount
        ]
        action = "added_mounts_array"
    else:
        # Mounts exist, add Claude if not present
        mounts = config['mounts']
        if isinstance(mounts, list):
            if any('claude' in m for m in mounts):
                print("⊘ Claude mount already exists", file=sys.stderr)
                sys.exit(1)
            mounts.append(claude_mount)
            action = "added_to_existing"
        else:
            print("✗ Mounts is not an array", file=sys.stderr)
            sys.exit(2)

    with open('.devcontainer/devcontainer.json', 'w') as f:
        json.dump(config, f, indent=2)

    print(f"✓ {action}")
    sys.exit(0)

except json.JSONDecodeError as e:
    print(f"✗ JSON parsing error: {e}", file=sys.stderr)
    sys.exit(2)
except Exception as e:
    print(f"✗ Error: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT

    UPDATE_RESULT=$?

    if [ $UPDATE_RESULT -eq 0 ]; then
        echo -e "  ${GREEN}✓ Updated devcontainer.json${NC}"
    elif [ $UPDATE_RESULT -eq 1 ]; then
        # Already has Claude mount
        ((SKIPPED++))
        cd ..
        continue
    else
        echo -e "  ${RED}✗ Failed to update devcontainer.json${NC}"
        mv .devcontainer/devcontainer.json.backup .devcontainer/devcontainer.json
        ((FAILED++))
        cd ..
        continue
    fi

    # Check if repo has uncommitted changes (it should)
    if ! git diff --quiet .devcontainer/devcontainer.json; then
        # Create branch and commit
        BRANCH_NAME="chore/add-claude-auth-mount"
        git checkout -b "${BRANCH_NAME}" 2>/dev/null || git checkout "${BRANCH_NAME}"

        git add .devcontainer/devcontainer.json
        git commit -m "$(cat <<'EOF'
chore: persist Claude authentication in devcontainer

Add Claude config directory mount to avoid re-authentication
when spinning up devcontainers.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

        # Push to remote
        if git push -u origin "${BRANCH_NAME}" 2>&1; then
            echo -e "  ${GREEN}✓ Pushed to ${BRANCH_NAME}${NC}"
            ((UPDATED++))
        else
            echo -e "  ${RED}✗ Failed to push (may need auth or permissions)${NC}"
            ((FAILED++))
        fi
    else
        echo -e "  ${YELLOW}⊘ No changes detected${NC}"
        ((SKIPPED++))
    fi

    cd ..
done <<< "$REPOS"

# Summary
echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "Total repos:     ${TOTAL_REPOS}"
echo -e "Processed:       ${PROCESSED}"
echo -e "${GREEN}Updated:         ${UPDATED}${NC}"
echo -e "${YELLOW}Skipped:         ${SKIPPED}${NC}"
echo -e "${RED}Failed:          ${FAILED}${NC}"
echo -e "\n${YELLOW}Clone directory: ${CLONE_DIR}${NC}"
echo -e "${YELLOW}You can safely delete it when done reviewing${NC}"

if [ "$UPDATED" -gt 0 ]; then
    echo -e "\n${GREEN}Next steps:${NC}"
    echo -e "1. Review the changes in the clone directory"
    echo -e "2. Create PRs from the pushed branches (chore/add-claude-auth-mount)"
    echo -e "3. Or merge directly if you're confident"
fi
