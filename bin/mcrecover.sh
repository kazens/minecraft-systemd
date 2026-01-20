#!/bin/bash
# Copyright (C) 2026 Karl Hastings <karl@passkeysec.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Configuration
BASE_DIR="/opt/minecraft/instances"
STATE_DIR="/dev/shm/minecraft_monitor"
MAX_FAILURES=3

# Ensure state directory exists with correct permissions
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

for dir in "$BASE_DIR"/*/; do
    [ -d "$dir" ] || continue
    INSTANCE=$(basename "$dir" | tr -d '\r\n')
    LOG_FILE="${dir}logs/latest.log"
    COUNT_FILE="$STATE_DIR/$INSTANCE.fail"
    
    # Check if the service is even supposed to be running
    STATUS=$(systemctl is-active "mcserver@$INSTANCE" 2>/dev/null)
    
    if [ "$STATUS" == "active" ]; then
        # --- THE SILENT PROBE ---
        # We use the same 'w' probe from the dashboard to check responsiveness
        ID=$((RANDOM % 9999))
        screen -S "mc-$INSTANCE" -X stuff "w [P-$ID] .\015" 2>/dev/null
        
        # Give the server 2 seconds to write the error to the log
        sleep 2
        
        if tail -n 10 "$LOG_FILE" 2>/dev/null | grep -q "\[P-$ID\]"; then
            # SUCCESS: Server is responsive. Reset failure count.
            rm -f "$COUNT_FILE"
        else
            # FAILURE: Server did not respond to the command (Zombie)
            FAILURES=0
            [ -f "$COUNT_FILE" ] && FAILURES=$(cat "$COUNT_FILE")
            FAILURES=$((FAILURES + 1))
            
            echo "$(date): Instance $INSTANCE failed probe. Strike $FAILURES/$MAX_FAILURES"
            
            if [ "$FAILURES" -ge "$MAX_FAILURES" ]; then
                echo "$(date): RECOVERING $INSTANCE - Sending restart command..."
                # Log the event to systemd journal for historical tracking
                echo "mcrecover: Restarting zombie instance $INSTANCE" | systemd-cat -t mcrecover -p alert
                
                # Clear counter and restart
                rm -f "$COUNT_FILE"
                systemctl restart "mcserver@$INSTANCE"
            else
                echo "$FAILURES" > "$COUNT_FILE"
            fi
        fi
    else
        # If the server is manually stopped, clear any old failure state
        rm -f "$COUNT_FILE"
    fi
done
