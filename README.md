# Minecraft Server Infrastructure

This repository contains a multi-instance Minecraft server environment managed by **systemd** and monitored by custom health and recovery scripts.

---

## 1. Service Management
The servers are managed as systemd template units. Replace `<name>` with the folder name of the instance found in `/opt/minecraft/instances/`.

* **Start a server:** `sudo systemctl start mcserver@<name>`
* **Stop a server:** `sudo systemctl stop mcserver@<name>`
* **Restart a server:** `sudo systemctl restart mcserver@<name>`
* **Check status:** `systemctl status mcserver@<name>`
* **View system logs:** `journalctl -u mcserver@<name> -f`

> **Note:** The stop command triggers a 15s in-game warning, an automated `save-all`, and a "Smart Wait" loop that allows the Java process to exit cleanly (Status 0) before systemd intervenes.

---

## 2. Console Interaction (Screen)
The servers run inside detached `screen` sessions.

* **Connect to a console:** `screen -r mc-<name>`
* **Disconnect (Detach):** Press `CTRL+A`, then `D`

⚠️ **WARNING:** Always use the detach sequence (`CTRL+A`, `D`) to leave the console. Closing the terminal window or using `CTRL+C` may interrupt the server process.

---

## 3. Monitoring & Provisioning Tools
Custom scripts are located in `/opt/minecraft/bin/`.

| Script | Purpose |
| :--- | :--- |
| `mchealth.sh` | **DASHBOARD:** Displays real-time RAM, Port status, Player counts, and Lag. |
| `mcrecover.sh` | **THE DOCTOR:** Automated script that detects and restarts "Zombie" instances. |
| `mcannounce.py` | **LAN BROADCASTER:** Announces server to the local network discovery list. |
| `mcmake.sh` | **CREATOR:** Provisions new server instances and manages master JAR files. |

---

## 4. Systemd & Security (system/ directory)
This project includes pre-configured systemd units and SELinux policy modules to ensure the services run with the least privilege necessary.

### Services & Timers
* `mcserver@.service`: The main server instance template.
* `mcannounce@.service`: Handles LAN discovery broadcasts per instance.
* `mc-monitor.service/timer`: Drives the `mcrecover.sh` health checks every 2 minutes.

### SELinux Policies
If you are running on a system with SELinux (like Fedora or RHEL), use these files to allow `screen` to run properly under systemd:
* `init-screen.te`: Type Enforcement file.
* `init-screen.mod` / `init-screen.pp`: Compiled policy modules.

---

## 5. Directory Structure
```text
/opt/minecraft/
├── bin/                # Management, Health, and Announcement scripts
├── jars/               # Master server.jar files
├── system/             # Systemd units and SELinux policy files
├── instances/          # Root for all server data
│   └── <name>/         # Individual instance folder
│       ├── server.properties
│       ├── server.env  # Optional: Define MEMORY=4096M
│       └── logs/       # latest.log is monitored here
└── README.md
