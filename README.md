# DevContainer Templates

**Stop re-authenticating with Claude every time you spin up devcontainers!**

This toolkit provides reusable devcontainer configurations and automation scripts to persist Claude CLI authentication across container rebuilds.

## What's Included

1. **Base Templates** - Ready-to-use devcontainer configs
   - [`base-devcontainer.json`](./base-devcontainer.json) - Standard Node.js setup with Claude auth
   - [`base-dockerfile`](./base-dockerfile) - Minimal Node.js 22 Dockerfile

2. **Automation Scripts**
   - [`update-single-repo.sh`](./update-single-repo.sh) - Update one repo at a time
   - [`update-all-devcontainers.sh`](./update-all-devcontainers.sh) - Bulk update all your repos

3. **Documentation**
   - [`USAGE.md`](./USAGE.md) - Detailed usage guide and troubleshooting
   - This README - Quick reference

## Quick Reference

### The Fix (What Gets Added)

Add this mount to your `devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
  ]
}
```

This mounts your host machine's Claude config directory (where the auth token lives) into the container, so you stay authenticated across rebuilds.

### Update Current Repo

```bash
~/devcontainer-templates/update-single-repo.sh
```

### Create New Project

```bash
cp ~/devcontainer-templates/base-devcontainer.json .devcontainer/devcontainer.json
cp ~/devcontainer-templates/base-dockerfile .devcontainer/Dockerfile
# Then customize for your project
```

## Why This Matters

Without this mount:
1. Start devcontainer
2. Run `claude` → prompted to authenticate
3. Rebuild container
4. Run `claude` → prompted to authenticate again 😤

With this mount:
1. Start devcontainer
2. Run `claude` → already authenticated ✨
3. Rebuild container
4. Run `claude` → still authenticated ✨

## Features of Base Template

- **Claude auth persistence** - No more re-authenticating
- **SSH keys mounted** - Git operations work seamlessly
- **Modern Node.js** - Node 22 with latest npm
- **Biome formatting** - Fast formatter and linter
- **Common extensions** - GitLens, ESLint, Claude Code
- **Port forwarding** - 3000 by default
- **Auto install** - Runs `npm install` on container create

## Next Steps

1. Read [`USAGE.md`](./USAGE.md) for detailed instructions
2. Test on one repo first with `update-single-repo.sh`
3. Roll out to all repos with `update-all-devcontainers.sh`
4. Use base templates for new projects

## Customization

The base templates are starting points. Common customizations:

- **Different user**: Change `remoteUser` and mount target paths
- **Python projects**: Swap Dockerfile base image
- **Additional mounts**: Add `.gitconfig`, AWS credentials, etc.
- **More ports**: Add to `forwardPorts` array
- **Different package manager**: Change `postCreateCommand`

See [USAGE.md](./USAGE.md) for examples.

## Location

All files are in: `~/devcontainer-templates/`

---

**No more repetitive conversations about devcontainer setup!** 🎉

Just reference these templates and scripts for all future projects.
