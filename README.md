# 🛠 Dev Container Setup

## 🔧 Local Build & Debug

Build the dev container image locally to debug Dockerfile or feature issues:

```powershell
docker build -f .devcontainer/Dockerfile .
```

```bash
docker build -f .devcontainer/Dockerfile .
```

Run the image interactively for debugging (no VS Code):

```powershell
# Windows PowerShell: mount workspace and host ~/.ssh (readonly)
docker run --rm -it \
	-v ${PWD}:/workspace \
	-v $env:HOME/.ssh:/home/vscode/.ssh:ro \
	-w /workspace \
	mcr.microsoft.com/devcontainers/base:ubuntu bash
```

```bash
# macOS/Linux Bash
docker run --rm -it \
	-v "$PWD":/workspace \
	-v "$HOME"/.ssh:/home/vscode/.ssh:ro \
	-w /workspace \
	mcr.microsoft.com/devcontainers/base:ubuntu bash
```

Useful checks inside the container:

- Fish terminal and banner are configured in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) and [.devcontainer/Dockerfile](.devcontainer/Dockerfile).
- SSH keys are not mounted by default. If needed, mount manually (see docker run examples above) or add a mount in devcontainer.json.

Dev Containers logs (VS Code):

- Command Palette → “Dev Containers: Show Log” → copy errors for troubleshooting.

## 🔐 SSH Keys (Optional)

By default, this Dev Container does not mount host SSH keys.

- Manual: Mount your keys when running the image interactively (examples above).
- Devcontainer: To enable in VS Code, add a mount in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json), for example:

```jsonc
// .devcontainer/devcontainer.json
{
  "mounts": ["source=~/.ssh,target=/home/vscode/.ssh,type=bind,readonly"],
}
```

If your keys aren’t visible in the container, verify your host has the `.ssh` folder and that the files are readable. You may also need to trust hosts or add entries to `known_hosts`.

## 🧩 Dotfiles

By default, this Dev Container applies dotfiles from [milesburton/dotfiles](https://github.com/milesburton/dotfiles).

- Default: `DOTFILES_REPO=https://github.com/milesburton/dotfiles` (set in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)).
- Override: Set `DOTFILES_REPO` to your repo URL (or set it empty to disable). On start, the container will clone to `~/.dotfiles` and run `install.sh` if present.

```jsonc
// .devcontainer/devcontainer.json
{
  "containerEnv": {
    "DOTFILES_REPO": "https://github.com/YOUR_USERNAME/dotfiles",
  },
}
```
