#!/bin/bash
set -e

# --- Step 1: Collect all user input first ---

# Language selection
echo "Choose installation language [default English]:"
echo "1) Polish"
echo "2) English"
read -p "Choice [1/2]: " LANG_CHOICE </dev/tty

if [ "$LANG_CHOICE" == "1" ]; then
    WP_LOCALE="pl_PL"
    SITE_TITLE="Moja Strona"
else
    WP_LOCALE="en_US"
    SITE_TITLE="My Website"
fi

# Admin credentials
ADMIN_USER="admin"
ADMIN_PASS="admin"
ADMIN_EMAIL="admin@example.com"

# Port selection
read -p "Enter port for WordPress [default 8000]: " WP_PORT </dev/tty
WP_PORT=${WP_PORT:-8000}

# Theme selection
read -p "Do you want to install the '_underscores' theme? [Y/n]: " INSTALL_THEME </dev/tty
INSTALL_THEME=${INSTALL_THEME:-Y}

# Plugins selection
PLUGIN_FILE="wp-init-plugins.txt"
SELECTED_PLUGINS=()
if [ -f "$PLUGIN_FILE" ]; then
    while read -r plugin; do
        plugin=$(echo "$plugin" | tr -d '\r') # remove CRLF if present
        [[ -z "$plugin" || "$plugin" =~ ^# ]] && continue
        read -p "Do you want to install plugin '$plugin'? [Y/n]: " INSTALL_PLUGIN </dev/tty
        INSTALL_PLUGIN=${INSTALL_PLUGIN:-Y}
        if [[ "$INSTALL_PLUGIN" =~ ^[Yy]$ ]]; then
            SELECTED_PLUGINS+=("$plugin")
        fi
    done < "$PLUGIN_FILE"
fi

# --- Step 2: Start containers ---
echo "🚀 Starting containers..."
docker compose up -d

# Wait fixed 20 seconds
echo "⏳ Waiting 20 seconds for WordPress to start..."
sleep 20

# --- Step 3: Ensure WP-CLI cache exists ---
docker exec -i wp mkdir -p /var/www/.wp-cli/cache
docker exec -i wp chown www-data:www-data /var/www/.wp-cli/cache

# Helper function to run WP-CLI with increased memory and allow-root
wp_exec() {
    docker exec -i wp php -d memory_limit=512M /usr/local/bin/wp "$@" --allow-root
}

# --- Step 4: Download latest WordPress ---
echo "⬇️ Downloading WordPress..."
wp_exec core download --force --locale="$WP_LOCALE"

# --- Step 5: Install WordPress ---
echo "⚙️ Installing WordPress (${WP_LOCALE})..."
wp_exec core install \
    --url="http://localhost:${WP_PORT}" \
    --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" \
    --skip-email

# --- Step 6: Remove default plugins ---
echo "🗑️ Removing default plugins (Akismet, Hello Dolly)..."
wp_exec plugin delete akismet hello-dolly || true
echo "✅ Default plugins removed!"

# --- Step 7: Install theme ---
if [[ "$INSTALL_THEME" =~ ^[Yy]$ ]]; then
    echo "🎨 Installing Underscores theme..."
    wp_exec theme install https://github.com/Automattic/_s/archive/refs/heads/master.zip --activate
    echo "✅ Underscores theme installed and activated!"
else
    echo "ℹ️ Skipping Underscores theme installation."
fi

# --- Step 8: Install selected plugins ---
if [ "${#SELECTED_PLUGINS[@]}" -gt 0 ]; then
    echo "📦 Installing selected plugins..."
    for plugin in "${SELECTED_PLUGINS[@]}"; do
        echo "🔧 Installing plugin '$plugin'..."
        wp_exec plugin install "$plugin" --activate
        echo "✅ Plugin '$plugin' installed!"
    done
else
    echo "ℹ️ No plugins selected for installation."
fi

# --- Step 9: Done ---
echo ""
echo "✅ WordPress installed!"
echo "🌐 Open the site: http://localhost:${WP_PORT}"
echo "🔑 Login details: ${ADMIN_USER} / ${ADMIN_PASS}"
