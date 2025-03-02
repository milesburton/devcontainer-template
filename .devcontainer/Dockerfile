# Use Ubuntu base image from Dev Containers
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies
RUN apt-get update && apt-get install -y \
  fish jq git unzip curl ripgrep \
  ssh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Fish Shell Plugins
RUN mkdir -p /home/vscode/.config/fish && \
  echo "set -U fish_greeting ''" >> /home/vscode/.config/fish/config.fish && \
  chown -R vscode:vscode /home/vscode/.config/fish

# Set Fish as default shell for vscode user
RUN chsh -s /usr/bin/fish vscode

# Ensure SSH directory has correct permissions
RUN chmod 700 /home/vscode/.ssh && \
  chown -R vscode:vscode /home/vscode/.ssh

# Set work directory
WORKDIR /workspace
