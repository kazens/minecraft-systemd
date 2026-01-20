#!/bin/bash

# Configuration
BASE_DIR="/opt/minecraft/instances"

# Helper function to pad strings before adding color
pad() {
    printf "%-${2}s" "$1"
}

# Header
printf "%-17s | %-8s | %-9s | %-7s | %-7s | %-7s | %-6s\n" \
       "INSTANCE" "STATUS" "NETWORK" "PLAYERS" "MEMORY" "RSS" "AGE"
echo "--------------------------------------------------------------------------------"

for dir in "$BASE_DIR"/*/; do
    [ -d "$dir" ] || continue
    INSTANCE=$(basename "$dir" | tr -d '\r\n')
    
    # 1. Extraction
    PORT=$(grep -m 1 "^server-port=" "${dir}server.properties" 2>/dev/null | cut -d= -f2 | tr -dc '0-9')
    PORT=${PORT:-"???"}

    if [ -f "${dir}server.env" ]; then
        CONF_RAM=$(grep -m 1 "MEMORY=" "${dir}server.env" 2>/dev/null | cut -d= -f2 | tr -dc '[:alnum:]')
    else
        CONF_RAM="2048M*" 
    fi

    # 2. Status & Health Checks
    STATUS=$(systemctl is-active "mcserver@$INSTANCE" 2>/dev/null | tr -d '\r\n')
    [ -z "$STATUS" ] && STATUS="unknown"
    
    LIVE_RSS="-"
    PLAYER_COUNT="-"
    AGE_VAL=0
    
    NET_STR="$PORT:OFF"
    NET_COLOR="\e[0;31m" 
    STATUS_COLOR="\e[0;33m" 
    AGE_DISP="-"
    AGE_COLOR="\e[0m"

    if [ "$STATUS" == "active" ]; then
        STATUS_COLOR="\e[0;32m"

        # Check Log Age
        LOG_FILE="${dir}logs/latest.log"
        if [ -f "$LOG_FILE" ]; then
            LAST_LOG=$(stat -c %Y "$LOG_FILE" 2>/dev/null)
            AGE_VAL=$(( $(date +%s) - LAST_LOG ))
            AGE_DISP="${AGE_VAL}s"
            
            if [ $AGE_VAL -lt 30 ]; then AGE_COLOR="\e[0;32m"
            elif [ $AGE_VAL -lt 90 ]; then AGE_COLOR="\e[0;33m"
            else AGE_COLOR="\e[0;31m"; fi
        fi

        # Network Check
        if [[ "$PORT" =~ ^[0-9]+$ ]] && ss -tuln | grep -q ":$PORT "; then
            if [ $AGE_VAL -lt 90 ]; then
                NET_STR="$PORT:UP"
                NET_COLOR="\e[0;32m"
            else
                NET_STR="$PORT:ZMB"
                NET_COLOR="\e[0;31m"
            fi
        else
            NET_STR="$PORT:ERR"
            NET_COLOR="\e[0;31m"
        fi

        # Get Live RAM
        PID=$(systemctl show "mcserver@$INSTANCE" --property=MainPID --value 2>/dev/null | tr -dc '0-9')
        if [ -n "$PID" ] && [ "$PID" -ne 0 ]; then
            RSS_KB=$(ps -o rss= -p "$PID" 2>/dev/null | tr -dc '0-9')
            [ -n "$RSS_KB" ] && LIVE_RSS="$(( RSS_KB / 1024 ))M"
        fi

        # 3. PLAYER COUNT LOGIC
        # We send 'list' and wait for log flush.
        screen -S "mc-$INSTANCE" -X stuff "list\015" 2>/dev/null
        sleep 0.4
        
        # Grab the line and extract just the number following "There are"
        PLAYER_INFO=$(tail -n 20 "$LOG_FILE" 2>/dev/null | grep "players online" | tail -n 1)
        if [ -n "$PLAYER_INFO" ]; then
            # Extract only the digit that appears before "of a max"
            P_CURRENT=$(echo "$PLAYER_INFO" | grep -oP 'There are \K[0-9]+')
            PLAYER_COUNT="${P_CURRENT:-0}"
        else
            PLAYER_COUNT="0"
        fi
    fi

    # Formatting and Padding
    C_INSTANCE=$(pad "$INSTANCE" 17)
    C_STATUS="${STATUS_COLOR}$(pad "$STATUS" 8)\e[0m"
    C_NET="${NET_COLOR}$(pad "$NET_STR" 9)\e[0m"
    C_PLAYERS=$(pad "$PLAYER_COUNT" 7)
    C_CONF=$(pad "$CONF_RAM" 7)
    C_RSS=$(pad "$LIVE_RSS" 7)
    C_AGE="${AGE_COLOR}$(pad "$AGE_DISP" 6)\e[0m"

    printf "%b | %b | %b | %b | %b | %b | %b\n" \
           "$C_INSTANCE" "$C_STATUS" "$C_NET" "$C_PLAYERS" "$C_CONF" "$C_RSS" "$C_AGE"

done
echo "--------------------------------------------------------------------------------"
