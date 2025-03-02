# 🛠 Dev Container Dotfiles Setup

## 🔹 Option 1: Use Your Own GitHub Dotfiles (Recommended)
If you have a **GitHub repository named `dotfiles`**, it will be **automatically cloned and applied** when you start this Dev Container.

📌 **Steps to Enable:**
1. Create a **public or private GitHub repo** called `dotfiles`.
2. Add your config files (`.bashrc`, `.gitconfig`, `config.fish`, etc.).
3. Restart the Dev Container – it will automatically pull your dotfiles!

---

## 🔹 Option 2: Use Default Dotfiles
If you **don’t have a GitHub `dotfiles` repo**, the Dev Container will use the included **default dotfiles** located in `.dotfiles/`.

📌 **To modify them**, just edit:
- `.dotfiles/.gitconfig`
- `.dotfiles/.bashrc`
- `.dotfiles/config.fish`

---

## 🔹 Option 3: Automatically Clone a Specific Dotfiles Repo
If you want to **force a specific dotfiles repo**, update `devcontainer.json` with:

```json
"postCreateCommand": "git clone https://github.com/YOUR_USERNAME/dotfiles ~/.dotfiles && bash ~/.dotfiles/install.sh"
