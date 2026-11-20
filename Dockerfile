FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --------------------------------------------------
# Base system
# --------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg git git-lfs \
    bash zsh sudo neovim \
    build-essential make cmake \
    locales unzip xz-utils tar procps \
    python3 python3-pip python3-venv python3-dev \
    python3-isort python3-pytest ipython3 python3-dotenv \
    nodejs npm \
    postgresql postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# --------------------------------------------------
# user
# --------------------------------------------------
RUN groupadd -g 1000 vscode && \
    useradd -m -u 1000 -g 1000 -s /bin/zsh vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode

# --------------------------------------------------
# tools (cached layers)
# --------------------------------------------------

ARG GH_VERSION=2.55.0

RUN arch="$(dpkg --print-architecture)" && \
    curl -fsSL \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.tar.gz" \
    -o /tmp/gh.tgz && \
    tar -xzf /tmp/gh.tgz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${arch}/bin/gh /usr/local/bin/gh

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# pnpm (fast + reproducible)
RUN npm install -g corepack
RUN corepack enable
RUN corepack prepare pnpm@9.12.2 --activate

# gvm (installs under the vscode user so it lands in ~vscode/.gvm)
RUN su - vscode -c 'curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash'

# oh-my-zsh
RUN su - vscode -c 'set -e; RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' \
    && ls -la /home/vscode/.zshrc

# shell init: gvm
RUN echo '[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"' >> /home/vscode/.zshrc

# prek (pre-commit) -> /usr/local/bin so every user gets it
RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) p=x86_64 ;; arm64) p=aarch64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac; \
    curl -fsSL "https://github.com/j178/prek/releases/download/v0.4.8/prek-${p}-unknown-linux-gnu.tar.gz" -o /tmp/prek.tgz && \
    tar -xzf /tmp/prek.tgz -C /tmp && \
    find /tmp -maxdepth 3 -type f -name 'prek' -exec install -m 755 {} /usr/local/bin/prek \; && \
    rm -rf /tmp/prek*

# --------------------------------------------------
# codespace lifecycle scripts (on PATH for devcontainers)
# --------------------------------------------------
COPY scripts/codespace-post-create scripts/codespace-post-start /usr/local/bin/
RUN chmod +x /usr/local/bin/codespace-post-create /usr/local/bin/codespace-post-start


# --------------------------------------------------
# runtime user
# --------------------------------------------------
USER vscode