# DevContainer Claude Auth - Quick Start

## The Problem

Re-authenticating with Claude every time you spin up a devcontainer is tiresome.

## The Solution

Mount `~/.config/claude/` into your devcontainer.

## Three Commands You Need

### 1. Fix Current Repo

```bash
~/devcontainer-templates/update-single-repo.sh
```

Then commit and push.

### 2. Fix All Repos (Interactive)

```bash
~/devcontainer-templates/find-and-update-all.sh ~/projects
```

Finds all devcontainers in `~/projects` and offers to update each one.

### 3. Fix All Repos from GitHub (Bulk)

```bash
~/devcontainer-templates/update-all-devcontainers.sh your-username
```

Clones all your repos, updates devcontainers, commits, and pushes.

## For New Projects

```bash
cp ~/devcontainer-templates/base-devcontainer.json .devcontainer/
cp ~/devcontainer-templates/base-dockerfile .devcontainer/
```

## Manual Fix

Add to your `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.config/claude,target=/home/node/.config/claude,type=bind"
  ]
}
```

## That's It!

Rebuild your devcontainer and never re-authenticate again.

---

**Full docs:** [`README.md`](./README.md) | [`USAGE.md`](./USAGE.md)
