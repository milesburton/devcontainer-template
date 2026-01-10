#!/bin/bash

# Script to update a single repo's devcontainer with Claude auth mount
# Usage: ./update-single-repo.sh [path-to-repo]

set -euo pipefail

REPO_PATH="${1:-.}"
cd "$REPO_PATH"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating devcontainer in: $(pwd)${NC}"

# Check if devcontainer exists
if [ ! -f ".devcontainer/devcontainer.json" ]; then
    echo -e "${RED}✗ No devcontainer found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Devcontainer found${NC}"

# Check if Claude mount already exists
if grep -q "\.config/claude" .devcontainer/devcontainer.json 2>/dev/null; then
    echo -e "${YELLOW}⊘ Claude mount already configured${NC}"
    exit 0
fi

# Backup original
cp .devcontainer/devcontainer.json .devcontainer/devcontainer.json.backup

# Update using Python
python3 << 'PYTHON_SCRIPT'
import json
import sys
import re

try:
    with open('.devcontainer/devcontainer.json', 'r') as f:
        content = f.read()

    # Handle JSON with comments (common in devcontainer.json)
    # Remove single-line comments
    lines = []
    for line in content.split('\n'):
        if '//' in line:
            # Keep content before comment
            code_part = line.split('//')[0]
            if code_part.strip():
                lines.append(code_part.rstrip())
        else:
            lines.append(line)
    clean_content = '\n'.join(lines)

    # Remove trailing commas before closing braces/brackets (common in commented JSON)
    clean_content = re.sub(r',(\s*[}\]])', r'\1', clean_content)

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
            if any('claude' in str(m) for m in mounts):
                print("⊘ Claude mount already exists", file=sys.stderr)
                sys.exit(1)
            mounts.append(claude_mount)
            action = "added_to_existing"
        else:
            print("✗ Mounts is not an array", file=sys.stderr)
            sys.exit(2)

    with open('.devcontainer/devcontainer.json', 'w') as f:
        json.dump(config, f, indent=2)
        f.write('\n')  # Add trailing newline

    print(f"✓ {action}")
    sys.exit(0)

except json.JSONDecodeError as e:
    print(f"✗ JSON parsing error: {e}", file=sys.stderr)
    print("Try manually adding the Claude mount", file=sys.stderr)
    sys.exit(2)
except Exception as e:
    print(f"✗ Error: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT

UPDATE_RESULT=$?

if [ $UPDATE_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Updated devcontainer.json${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Review the changes: git diff .devcontainer/devcontainer.json"
    echo "2. Commit: git add .devcontainer/devcontainer.json && git commit -m 'chore: persist Claude auth in devcontainer'"
    echo "3. Push: git push"
elif [ $UPDATE_RESULT -eq 1 ]; then
    echo -e "${YELLOW}⊘ Already has Claude mount${NC}"
else
    echo -e "${RED}✗ Failed to update devcontainer.json${NC}"
    if [ -f ".devcontainer/devcontainer.json.backup" ]; then
        mv .devcontainer/devcontainer.json.backup .devcontainer/devcontainer.json
        echo -e "${YELLOW}Restored backup${NC}"
    fi
    exit 1
fi
