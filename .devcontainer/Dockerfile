FROM mcr.microsoft.com/devcontainers/base:ubuntu
ARG ENABLE_FISH_BANNER=1
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates gnupg \
  fish jq git unzip curl ripgrep \
  ssh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get update && apt-get install -y --no-install-recommends nodejs && \
  apt-get clean && rm -rf /var/lib/apt/lists/*
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npx -y playwright install-deps && \
  npx -y playwright install && \
  chown -R vscode:vscode /ms-playwright
RUN if [ "$ENABLE_FISH_BANNER" = "1" ]; then \
  mkdir -p /home/vscode/.config/fish && \
  { \
    echo '# Environment setup'; \
    echo 'if status is-interactive'; \
    echo '  echo ""'; \
    echo '  echo "----------------------------------------------"'; \
    echo '  echo "Welcome to the TypeScript Dev Container!"'; \
    echo '  echo "Node, pnpm, and Playwright are ready."'; \
    echo '  echo "----------------------------------------------"'; \
    echo '  echo ""'; \
    echo 'end'; \
  } > /home/vscode/.config/fish/config.fish && \
  chown -R vscode:vscode /home/vscode/.config/fish; \
  fi
RUN install -d -m 700 -o vscode -g vscode /home/vscode/.ssh
USER vscode
WORKDIR /workspace