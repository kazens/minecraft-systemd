#!/bin/bash

# Configuration
BASE_DIR="/opt/minecraft/instances"
BIN_DIR="/opt/minecraft/bin"
JAR_STORAGE="/opt/minecraft/jars"
MANIFEST_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"

# Defaults
INSTANCE_NAME=""
VERSION="latest"
MOTD=""
SEED=""
USE_DEFAULTS=false

usage() {
    echo "Usage: $0 -n <name> [-v <version>] [-m <motd>] [-s <seed>] [--defaults]"
    exit 1
}

# Strip C0/C1 control characters and DEL (keeps UTF-8 and printable text)
strip_controls() {
    LC_ALL=C printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177'
}

# 1. Parse Args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) INSTANCE_NAME="$2"; shift ;;
        -v|--version) VERSION="$2"; shift ;;
        -m|--motd) MOTD="$2"; shift ;;
        -s|--seed) SEED="$2"; shift ;;
        --defaults) USE_DEFAULTS=true ;;
        *) usage ;;
    esac
    shift
done

# 2. Input & Sanitization
[ -z "$INSTANCE_NAME" ] && read -r -p "Instance name: " INSTANCE_NAME
INSTANCE_NAME="${INSTANCE_NAME//[^a-zA-Z0-9._-]/}"
if [ -z "$INSTANCE_NAME" ]; then
    echo "Error: Instance name is empty or invalid after sanitization."
    exit 1
fi

INSTANCE_PATH="$BASE_DIR/$INSTANCE_NAME"
if [ -d "$INSTANCE_PATH" ]; then
    echo "Error: Instance '$INSTANCE_NAME' already exists."
    exit 1
fi

if [ "$USE_DEFAULTS" = false ]; then
    [ "$VERSION" == "latest" ] && read -r -p "Version [latest]: " input_v && VERSION=${input_v:-latest}
    [ -z "$MOTD" ] && read -r -p "MOTD: " input_m && MOTD=${input_m:-"Minecraft Server $INSTANCE_NAME"}
    [ -z "$SEED" ] && read -r -p "Seed: " input_s && SEED=${input_s:-""}
else
    MOTD=${MOTD:-"Minecraft Server $INSTANCE_NAME"}
fi

MOTD=$(strip_controls "$MOTD")
SEED=$(strip_controls "$SEED")

# 3. Resolve Version
echo "Resolving version..."
MANIFEST_JSON=$(curl -s "$MANIFEST_URL")
if [ -z "$MANIFEST_JSON" ]; then
    echo "Error: Failed to download version manifest (empty response)."
    exit 1
fi

if [ "$VERSION" == "latest" ]; then
    VERSION=$(jq -r '.latest.release' <<< "$MANIFEST_JSON")
fi
VERSION="${VERSION//[^a-zA-Z0-9.]/}"

VERSION_URL=$(jq -r --arg V "$VERSION" '.versions[] | select(.id == $V) | .url' <<< "$MANIFEST_JSON")
if [ -z "$VERSION_URL" ] || [ "$VERSION_URL" == "null" ]; then
    echo "Error: Version $VERSION not found."; exit 1
fi

DOWNLOAD_URL=$(curl -s "$VERSION_URL" | jq -r '.downloads.server.url')
FULL_JAR_NAME="minecraft_server.$VERSION.jar"

# 4. Handle JARs (As minecraft user)
mkdir -p "$JAR_STORAGE"
if [ ! -f "$JAR_STORAGE/$FULL_JAR_NAME" ]; then
    echo "Downloading $VERSION..."
    curl -s -o "$JAR_STORAGE/$FULL_JAR_NAME" "$DOWNLOAD_URL"
fi

# 5. Setup Instance
mkdir -p "$INSTANCE_PATH"
ln -sf "$JAR_STORAGE/$FULL_JAR_NAME" "$INSTANCE_PATH/minecraft_server.jar"

# 6. Port Selection
PORT=25565
while grep -rq "server-port=$PORT" "$BASE_DIR"; do
    ((PORT++))
done

# 7. Write Configs (printf: values are data, not re-parsed as shell code)
printf '%s\n' "server-port=$PORT" "motd=$MOTD" "level-seed=$SEED" "online-mode=true" > "$INSTANCE_PATH/server.properties"
echo "eula=true" > "$INSTANCE_PATH/eula.txt"

# 8. Service Activation (Using Sudo)
echo "Activating Services..."
sudo /usr/bin/systemctl daemon-reload
sudo /usr/bin/systemctl enable --now mcserver@"$INSTANCE_NAME"
sudo /usr/bin/systemctl enable --now mcannounce@"$INSTANCE_NAME"

echo "------------------------------------------------"
echo "Done. Instance '$INSTANCE_NAME' ($VERSION) is running on port $PORT."
