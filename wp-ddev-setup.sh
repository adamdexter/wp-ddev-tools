#!/bin/bash
#
# wp-ddev-setup.sh — One-command WordPress DDEV local development setup
# Part of wp-ddev-tools: https://github.com/yourname/wp-ddev-tools
#
# Sets up a complete local WordPress development environment with DDEV,
# cloned from a live site via SSH. Handles Docker, DDEV, HTTPS, Git,
# SSH config, file sync, database import, URL replacement, and
# persistent config fixes.
#
# Usage: ./wp-ddev-setup.sh
#

set -e

# ─── Colors ───
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ───
step_num=0
total_steps=0

step() {
    step_num=$((step_num + 1))
    echo ""
    echo -e "${BOLD}${CYAN}━━━ Step $step_num: $1 ━━━${NC}"
    echo ""
}

ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}~${NC} $1"
}

fail() {
    echo -e "  ${RED}✗ $1${NC}"
    exit 1
}

ask() {
    local prompt="$1"
    local default="$2"
    local var="$3"
    if [ -n "$default" ]; then
        echo -ne "  ${BOLD}$prompt${NC} ${DIM}[$default]${NC}: "
    else
        echo -ne "  ${BOLD}$prompt${NC}: "
    fi
    read input
    if [ -z "$input" ] && [ -n "$default" ]; then
        eval "$var='$default'"
    else
        eval "$var='$input'"
    fi
}

ask_yn() {
    local prompt="$1"
    local default="$2"
    echo -ne "  ${BOLD}$prompt${NC} ${DIM}[$default]${NC}: "
    read input
    input="${input:-$default}"
    case "$input" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# ─── Banner ───
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  WordPress DDEV Local Development Setup${NC}"
echo -e "${BOLD}  Clone your live WordPress site into a local dev environment${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${DIM}This script will walk you through setting up a complete local${NC}"
echo -e "  ${DIM}WordPress dev environment with DDEV, synced from your live site.${NC}"
echo -e "  ${DIM}You can exit at any time with Ctrl+C.${NC}"
echo ""

# ─── Gather Info ───
step "Project Info"

ask "Project name (lowercase, no spaces — used for folder and DDEV site)" "my-wp-site" PROJECT_NAME
ask "Project directory" "$HOME/Projects/$PROJECT_NAME" PROJECT_DIR

echo ""
echo -e "  ${DIM}Your local site will be at: https://$PROJECT_NAME.ddev.site${NC}"
echo ""

# ─── Live Site Info ───
step "Live Site Connection"

echo -e "  ${DIM}We need SSH access to your live site to pull files and database.${NC}"
echo ""

ask "SSH host (hostname or IP)" "" SSH_HOSTNAME
ask "SSH username" "" SSH_USER
ask "SSH port" "22" SSH_PORT
ask "Path to WordPress on the server" "~/public_html" REMOTE_PATH
ask "Live site URL (e.g. https://example.com)" "" LIVE_URL
ask "SSH key file" "$HOME/.ssh/id_ed25519" SSH_KEY

# Strip trailing slash from URL
LIVE_URL="${LIVE_URL%/}"
LOCAL_URL="https://$PROJECT_NAME.ddev.site"

# ─── SSH Alias ───
SSH_ALIAS="$PROJECT_NAME-live"

echo ""
echo -e "  ${DIM}Summary:${NC}"
echo -e "  ${DIM}  Project:    $PROJECT_NAME${NC}"
echo -e "  ${DIM}  Local URL:  $LOCAL_URL${NC}"
echo -e "  ${DIM}  Live URL:   $LIVE_URL${NC}"
echo -e "  ${DIM}  SSH:        $SSH_USER@$SSH_HOSTNAME:$SSH_PORT${NC}"
echo -e "  ${DIM}  Remote WP:  $REMOTE_PATH${NC}"
echo ""

if ! ask_yn "Continue with these settings?" "Y"; then
    echo "  Exiting."
    exit 0
fi

# ─── Prerequisites ───
step "Checking Prerequisites"

# Homebrew
if command_exists brew; then
    ok "Homebrew installed"
else
    fail "Homebrew is required. Install from https://brew.sh"
fi

# Docker
if command_exists docker && docker ps > /dev/null 2>&1; then
    ok "Docker is running"
else
    if command_exists docker; then
        warn "Docker is installed but not running"
    else
        echo ""
        echo -e "  ${DIM}DDEV needs a Docker engine. Choose one:${NC}"
        echo -e "  ${DIM}  1. OrbStack (recommended — fastest, easiest)${NC}"
        echo -e "  ${DIM}  2. Colima (free, open-source)${NC}"
        echo -e "  ${DIM}  3. Docker Desktop${NC}"
        echo ""
        ask "Choice" "1" DOCKER_CHOICE

        case "$DOCKER_CHOICE" in
            1)
                echo -e "  Installing OrbStack..."
                brew install orbstack
                echo -e "  ${YELLOW}Please open OrbStack from Applications, choose 'Docker', then re-run this script.${NC}"
                exit 0
                ;;
            2)
                echo -e "  Installing Colima..."
                brew install colima docker
                colima start --cpu 4 --memory 6 --disk 100 --vm-type=vz --mount-type=virtiofs --dns=1.1.1.1
                ;;
            3)
                echo -e "  ${YELLOW}Please install Docker Desktop from https://docker.com, start it, then re-run this script.${NC}"
                exit 0
                ;;
        esac
    fi

    # Verify Docker is now running
    docker ps > /dev/null 2>&1 || fail "Docker is not running. Please start your Docker provider and re-run."
    ok "Docker is running"
fi

# DDEV
if command_exists ddev; then
    ok "DDEV installed ($(ddev version -j 2>/dev/null | grep -o '"cli":"[^"]*"' | cut -d'"' -f4 || echo 'unknown version'))"
else
    echo -e "  Installing DDEV..."
    brew install ddev/ddev/ddev
    ok "DDEV installed"
fi

# mkcert
if command_exists mkcert; then
    ok "mkcert installed"
else
    echo -e "  Installing mkcert for local HTTPS..."
    brew install mkcert nss
    mkcert -install
    ok "mkcert installed and configured"
fi

# Git
if command_exists git; then
    ok "Git installed"
else
    fail "Git is required. Install with: brew install git"
fi

# WP-CLI on remote (we'll check later during SSH test)

# ─── SSH Setup ───
step "Setting Up SSH Access"

# Check if key exists
if [ -f "$SSH_KEY" ]; then
    ok "SSH key found at $SSH_KEY"
else
    if ask_yn "No SSH key found at $SSH_KEY. Generate one?" "Y"; then
        ask "Email for SSH key" "" SSH_EMAIL
        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY"
        echo ""
        echo -e "  ${YELLOW}Public key (add this to your hosting provider):${NC}"
        echo ""
        cat "${SSH_KEY}.pub"
        echo ""
        echo -e "  ${YELLOW}Add this key to your hosting provider's SSH settings, then press Enter to continue.${NC}"
        read -p "  "
    else
        fail "SSH key required for live site access."
    fi
fi

# Add SSH config alias
if grep -q "Host $SSH_ALIAS" ~/.ssh/config 2>/dev/null; then
    warn "SSH alias '$SSH_ALIAS' already exists in ~/.ssh/config"
else
    mkdir -p ~/.ssh
    cat >> ~/.ssh/config << EOF

Host $SSH_ALIAS
    HostName $SSH_HOSTNAME
    User $SSH_USER
    Port $SSH_PORT
    IdentityFile $SSH_KEY
EOF
    ok "SSH alias '$SSH_ALIAS' added to ~/.ssh/config"
fi

# Load SSH key into agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi
ssh-add -l 2>/dev/null | grep -q "ed25519" 2>/dev/null || ssh-add "$SSH_KEY" 2>/dev/null

# Test connection
echo -e "  Testing SSH connection..."
if ssh -o ConnectTimeout=10 "$SSH_ALIAS" "echo connected" > /dev/null 2>&1; then
    ok "SSH connection successful"
else
    fail "Cannot connect to $SSH_ALIAS. Check your credentials and SSH key."
fi

# Check WP-CLI on remote
if ssh "$SSH_ALIAS" "cd $REMOTE_PATH && wp --version" > /dev/null 2>&1; then
    ok "WP-CLI available on remote"
else
    fail "WP-CLI not found on remote server. It's required for database export."
fi

# ─── Detect Live Environment ───
step "Detecting Live Environment"

echo -e "  ${DIM}Reading PHP version, DB version, and table prefix from live site...${NC}"

REMOTE_SCRIPT=$(mktemp)
cat > "$REMOTE_SCRIPT" << 'ENDSCRIPT'
cd $1
echo "===PHP==="
php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION.PHP_EOL;' 2>/dev/null || echo "unknown"
echo "===DB==="
wp db query 'SELECT VERSION();' --skip-column-names 2>/dev/null | head -1 || echo "unknown"
echo "===PREFIX==="
wp config get table_prefix 2>/dev/null || echo "wp_"
echo "===WP==="
wp core version 2>/dev/null || echo "unknown"
echo "===END==="
ENDSCRIPT

LIVE_DATA=$(ssh "$SSH_ALIAS" "bash -s $REMOTE_PATH" < "$REMOTE_SCRIPT" 2>/dev/null)
rm -f "$REMOTE_SCRIPT"

# Parse
LIVE_PHP=$(echo "$LIVE_DATA" | sed -n '/===PHP===/,/===/p' | grep -v "===" | head -1)
LIVE_DB_FULL=$(echo "$LIVE_DATA" | sed -n '/===DB===/,/===/p' | grep -v "===" | head -1)
LIVE_PREFIX=$(echo "$LIVE_DATA" | sed -n '/===PREFIX===/,/===/p' | grep -v "===" | head -1)
LIVE_WP=$(echo "$LIVE_DATA" | sed -n '/===WP===/,/===/p' | grep -v "===" | head -1)

# Determine DB engine and version
if echo "$LIVE_DB_FULL" | grep -qi "maria"; then
    DB_ENGINE="mariadb"
    DB_VERSION=$(echo "$LIVE_DB_FULL" | grep -oP '^\d+\.\d+')
else
    DB_ENGINE="mysql"
    DB_VERSION=$(echo "$LIVE_DB_FULL" | grep -oP '^\d+\.\d+')
fi

ok "WordPress: $LIVE_WP"
ok "PHP: $LIVE_PHP"
ok "Database: $DB_ENGINE $LIVE_DB_FULL"
ok "Table prefix: $LIVE_PREFIX"

# ─── Create Project ───
step "Creating DDEV Project"

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Configure DDEV
ddev config \
    --project-type=wordpress \
    --project-name="$PROJECT_NAME" \
    --php-version="$LIVE_PHP" \
    --database="$DB_ENGINE:$DB_VERSION" \
    > /dev/null 2>&1

ok "DDEV configured (PHP $LIVE_PHP, $DB_ENGINE $DB_VERSION)"

# Create post-start hooks if non-standard prefix
if [ "$LIVE_PREFIX" != "wp_" ]; then
    cat > .ddev/config.local.yaml << EOF
hooks:
  post-start:
    - exec: "sed -i \"s/table_prefix = 'wp_'/table_prefix = '${LIVE_PREFIX}'/\" /var/www/html/wp-config-ddev.php"
    - exec: "sed -i \"s/define( 'WP_DEBUG', true )/define( 'WP_DEBUG', false )/\" /var/www/html/wp-config-ddev.php"
EOF
    ok "Post-start hooks created (table prefix: $LIVE_PREFIX, WP_DEBUG: false)"
else
    cat > .ddev/config.local.yaml << EOF
hooks:
  post-start:
    - exec: "sed -i \"s/define( 'WP_DEBUG', true )/define( 'WP_DEBUG', false )/\" /var/www/html/wp-config-ddev.php"
EOF
    ok "Post-start hooks created (WP_DEBUG: false)"
fi

# Start DDEV and download WordPress
ddev start > /dev/null 2>&1
ok "DDEV started"

ddev wp core download > /dev/null 2>&1
ok "WordPress $LIVE_WP downloaded"

# ─── Sync Files ───
step "Syncing Files from Live Site"

echo -e "  ${DIM}This may take a while depending on your site size...${NC}"
echo ""

echo -e "  Syncing plugins..."
rsync -avz -e "ssh -p $SSH_PORT" \
    "$SSH_ALIAS:$REMOTE_PATH/wp-content/plugins/" \
    wp-content/plugins/ > /dev/null 2>&1
ok "Plugins synced"

echo -e "  Syncing themes..."
rsync -avz -e "ssh -p $SSH_PORT" \
    "$SSH_ALIAS:$REMOTE_PATH/wp-content/themes/" \
    wp-content/themes/ > /dev/null 2>&1
ok "Themes synced"

if ask_yn "Sync uploads/media? (can be large)" "Y"; then
    echo -e "  Syncing uploads (this is usually the largest transfer)..."
    rsync -avz -e "ssh -p $SSH_PORT" \
        "$SSH_ALIAS:$REMOTE_PATH/wp-content/uploads/" \
        wp-content/uploads/ > /dev/null 2>&1
    ok "Uploads synced"
else
    warn "Skipped uploads — images may appear broken locally"
fi

# ─── Database ───
step "Importing Database"

echo -e "  Exporting live database..."
ssh "$SSH_ALIAS" "cd $REMOTE_PATH && wp db export ~/wp-ddev-setup-backup.sql" > /dev/null 2>&1
ok "Live database exported"

echo -e "  Downloading..."
scp "$SSH_ALIAS:~/wp-ddev-setup-backup.sql" . > /dev/null 2>&1
ok "Downloaded ($(du -h wp-ddev-setup-backup.sql | cut -f1))"

echo -e "  Importing..."
ddev import-db --file=wp-ddev-setup-backup.sql > /dev/null 2>&1
ok "Database imported"

# Restart to apply hooks (prefix fix)
ddev restart > /dev/null 2>&1
ok "DDEV restarted (config hooks applied)"

# Clean up
rm -f wp-ddev-setup-backup.sql
ssh "$SSH_ALIAS" "rm -f ~/wp-ddev-setup-backup.sql" > /dev/null 2>&1
ok "Temp files cleaned up"

# ─── URL Replacement ───
step "Configuring Local URLs"

REPLACEMENTS=$(ddev wp search-replace "$LIVE_URL" "$LOCAL_URL" --all-tables 2>&1 | grep -o '[0-9]* replacements' | head -1)
ok "search-replace: $REPLACEMENTS"

ddev wp option update siteurl "$LOCAL_URL" > /dev/null 2>&1
ddev wp option update home "$LOCAL_URL" > /dev/null 2>&1
ddev wp cache flush > /dev/null 2>&1
ddev wp rewrite flush > /dev/null 2>&1
ok "URLs updated and caches flushed"

# ─── Git ───
step "Setting Up Git"

if [ -d ".git" ]; then
    warn "Git already initialized"
else
    git init > /dev/null 2>&1

    cat > .gitignore << 'GITIGNORE'
# WordPress Core
/wp-admin/
/wp-includes/
/wp-*.php
/index.php
/license.txt
/readme.html
/xmlrpc.php

# Uploads (too large for git)
/wp-content/uploads/

# Database dumps
*.sql

# DDEV (track config, ignore generated)
.ddev/.dbimageBuild/
.ddev/.ddev-docker-compose-*
.ddev/.global_commands/
.ddev/.homeadditions/
.ddev/.importdb*
.ddev/.sshimageBuild/
.ddev/.webimageBuild/
.ddev/db_snapshots/
.ddev/sequelpro.spf
.ddev/import.yaml
.ddev/import-db/
.ddev/*-build/
.ddev/xhprof/

# System
.DS_Store
*.log
node_modules/
.env
GITIGNORE

    git add .
    git commit -m "Initial commit: DDEV config + WordPress wp-content" > /dev/null 2>&1
    ok "Git initialized with .gitignore"
fi

if command_exists gh; then
    if ask_yn "Create a GitHub repo?" "Y"; then
        ask "Repo visibility" "private" GH_VIS
        gh repo create "$PROJECT_NAME" "--$GH_VIS" --source=. --push > /dev/null 2>&1
        ok "GitHub repo created and pushed"
    fi
else
    warn "GitHub CLI (gh) not installed — skipping repo creation"
fi

# ─── Generate Helper Scripts ───
step "Installing Helper Scripts"

# Write config file for helper scripts
cat > .wp-ddev-tools.conf << EOF
# wp-ddev-tools configuration
# Generated by wp-ddev-setup.sh on $(date -Iseconds)
SSH_HOST="$SSH_ALIAS"
SSH_PORT="$SSH_PORT"
REMOTE_ROOT="$REMOTE_PATH"
LOCAL_URL="$LOCAL_URL"
LIVE_URL="$LIVE_URL"
TABLE_PREFIX="$LIVE_PREFIX"
EOF

ok "Config saved to .wp-ddev-tools.conf"
echo -e "  ${DIM}Helper scripts (sync-from-live.sh, verify-env.sh) will read this file.${NC}"

# ─── Done ───
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✓ Setup complete!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Your local site:${NC}  $LOCAL_URL"
echo -e "  ${BOLD}Project folder:${NC}   $PROJECT_DIR"
echo -e "  ${BOLD}SSH alias:${NC}        $SSH_ALIAS"
echo ""
echo -e "  ${BOLD}Quick reference:${NC}"
echo -e "  ${DIM}  Start:          ddev start${NC}"
echo -e "  ${DIM}  Open browser:    ddev launch${NC}"
echo -e "  ${DIM}  Stop:            ddev stop${NC}"
echo -e "  ${DIM}  WP admin:        ddev launch wp-admin${NC}"
echo -e "  ${DIM}  Sync from live:  ./sync-from-live.sh${NC}"
echo -e "  ${DIM}  Verify parity:   ./verify-env.sh${NC}"
echo -e "  ${DIM}  DB snapshot:     ddev snapshot --name=before-changes${NC}"
echo -e "  ${DIM}  Restore:         ddev snapshot restore before-changes${NC}"
echo ""
echo -e "  ${DIM}Open your site now:${NC}"
echo -e "  ${BOLD}  ddev launch${NC}"
echo ""
