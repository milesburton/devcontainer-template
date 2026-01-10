# DevContainer Templates - Usage Guide

Stop re-authenticating with Claude every time you spin up a devcontainer!

## Quick Start

### Option 1: Update a Single Repo

```bash
cd /path/to/your/repo
~/devcontainer-templates/update-single-repo.sh
```

This will:
1. Check if devcontainer exists
2. Add Claude config mount to persist authentication
3. Show you the changes
4. Provide commit/push instructions

### Option 2: Update Multiple Repos (Bulk)

```bash
# Test on first 5 repos
~/devcontainer-templates/update-all-devcontainers.sh your-github-username 5

# Run on all repos
~/devcontainer-templates/update-all-devcontainers.sh your-github-username
```

**Note**: Bulk update requires GitHub API access and will clone repos temporarily.

### Option 3: Manual Update

Add this to your `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly",
    "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
  ]
}
```

If you already have a `mounts` array, just add the Claude line:

```json
"source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
```

## What This Does

The Claude CLI stores its authentication token in `~/.config/claude/` on your host machine. By mounting this directory into your devcontainer, the container will reuse the same authentication token instead of prompting you to log in again.

## For New Projects

Use the base templates:

```bash
mkdir -p .devcontainer
cp ~/devcontainer-templates/base-devcontainer.json .devcontainer/devcontainer.json
cp ~/devcontainer-templates/base-dockerfile .devcontainer/Dockerfile
```

Then customize the name, ports, and extensions for your project.

## Troubleshooting

### Permission Issues

If you get permission errors, ensure the remoteUser matches the mount paths:

```json
{
  "remoteUser": "node",
  "mounts": [
    "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
  ]
}
```

### Different User

If your devcontainer uses a different user (e.g., `vscode`), update the target path:

```json
"source=${localEnv:HOME}/.config/claude,target=/home/vscode/.config/claude,type=bind"
```

### Still Prompting for Auth

1. Check that `~/.config/claude/` exists on your host machine
2. Verify you're authenticated on the host: `claude --version`
3. Rebuild the devcontainer: "Dev Containers: Rebuild Container"
4. Check mount worked: `ls ~/.config/claude/` inside the container

## Applying to All Your Repos

### Interactive Approach (Recommended)

Create a simple script to iterate through your repos:

```bash
# Create list of your repos with devcontainers
for repo in ~/projects/*; do
    if [ -f "$repo/.devcontainer/devcontainer.json" ]; then
        echo "Updating $repo"
        ~/devcontainer-templates/update-single-repo.sh "$repo"

        # Auto-commit and push
        cd "$repo"
        if git diff --quiet; then
            echo "  Already up to date"
        else
            git add .devcontainer/devcontainer.json
            git commit -m "chore: persist Claude auth in devcontainer"
            git push
        fi
    fi
done
```

### One-Time Setup for New Machines

Add this to your dotfiles or setup script to ensure all future devcontainers include Claude auth:

```bash
# In your ~/.bashrc or setup script
export DEVCONTAINER_MOUNTS='[
  "source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly",
  "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
]'
```

## Next Steps

1. Test on one repo first
2. Verify Claude works without re-auth after rebuilding
3. Roll out to remaining repos
4. Update your project templates/boilerplates

## Questions?

- Template location: `~/devcontainer-templates/`
- Scripts:
  - Single repo: `~/devcontainer-templates/update-single-repo.sh`
  - Bulk update: `~/devcontainer-templates/update-all-devcontainers.sh`
- Base templates: `~/devcontainer-templates/base-*`
