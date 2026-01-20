================================================================================
                    MINECRAFT SERVER INFRASTRUCTURE
================================================================================

This directory contains a multi-instance Minecraft server environment managed 
by systemd and monitored by custom health/recovery scripts.

--------------------------------------------------------------------------------
1. SERVICE MANAGEMENT
--------------------------------------------------------------------------------
Servers are managed as systemd template units. Replace <name> with the folder 
name of the instance found in /opt/minecraft/instances/.

* Start a server:      sudo systemctl start mcserver@<name>
* Stop a server:       sudo systemctl stop mcserver@<name>
* Restart a server:    sudo systemctl restart mcserver@<name>
* Check status:        systemctl status mcserver@<name>
* View system logs:    journalctl -u mcserver@<name> -f

Note: The stop command triggers a 15s in-game warning, an automated save-all, 
and a "Smart Wait" loop that allows the Java process to exit cleanly with 
status 0 before systemd intervenes.

--------------------------------------------------------------------------------
2. CONSOLE INTERACTION (SCREEN)
--------------------------------------------------------------------------------
The servers run inside detached 'screen' sessions.

* Connect to a console:    screen -r mc-<name>
* Disconnect (Detach):     Press CTRL+A, then D

WARNING: Always use the detach sequence (CTRL+A, D) to leave the console. 
Closing the terminal window or using CTRL+C may interrupt the server process 
depending on current shell focus.

--------------------------------------------------------------------------------
3. MONITORING & PROVISIONING TOOLS
--------------------------------------------------------------------------------
Custom scripts are located in /opt/minecraft/bin/ (added to $PATH).

* mchealth.sh   - DASHBOARD: Displays real-time RAM usage, Port status, 
                  Player counts, and Log Heartbeat (Age).
* mcrecover.sh  - THE DOCTOR: An automated script (run via systemd timer) 
                  that detects "Zombies" (Port is listening, but Log is dead).
* mcmake.sh     - CREATOR: Helper script to provision new server instances. 
                  It downloads the required server.jar and stores a master 
                  copy in /opt/minecraft/jars/ for instance deployment.

--------------------------------------------------------------------------------
4. INFRASTRUCTURE LOGIC
--------------------------------------------------------------------------------
* RECOVERY STATE: Failure counts are stored in /dev/shm/minecraft_monitor. 
  The script enforces strict ownership and type checks to prevent tampering.
* ZOMBIE DETECTION: A server is flagged as a "Zombie" if it is active but 
  its latest.log hasn't been modified in > 90 seconds. 
* AUTO-RECOVERY: Managed by 'mc-monitor.timer'. To disable all automated 
  restarts for maintenance, run: 
  sudo systemctl stop mc-monitor.timer

--------------------------------------------------------------------------------
5. DIRECTORY STRUCTURE
--------------------------------------------------------------------------------
/opt/minecraft/
├── bin/                # Management & Health scripts
├── jars/               # Master copies of server.jar files (managed by mcmake)
├── instances/          # Root for all server data
│   └── <name>/         # Individual instance folder
│       ├── server.properties
│       ├── server.env  # Optional: Define MEMORY=4096M
│       └── logs/       # Heartbeat/Age monitored here via latest.log
└── README.txt          # This file
--------------------------------------------------------------------------------
# minecraft-systemd
