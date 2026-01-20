# Minecraft Server Infrastructure

This repository contains a multi-instance Minecraft server environment managed by **systemd** and monitored by custom health and recovery scripts. It is designed for high-availability, resource efficiency, and security.

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
The servers run inside detached `screen` sessions for direct console access.

* **Connect to a console:** `screen -r mc-<name>`
* **Disconnect (Detach):** Press `CTRL+A`, then `D`

⚠️ **WARNING:** Always use the detach sequence (`CTRL+A`, `D`) to leave the console. Closing the terminal window or using `CTRL+C` while attached may interrupt the server process.
---

## 3. Monitoring & Provisioning Tools
Custom scripts are located in `/opt/minecraft/bin/`.

| Script | Purpose |
| :--- | :--- |
| `mchealth.sh` | **DASHBOARD:** Displays real-time RAM, Port status, Player counts, and Lag. |
| `mcrecover.sh` | **THE DOCTOR:** Automated script that detects and restarts "Zombie" instances. |
| `mcannounce.py` | **LAN BROADCASTER:** Announces server to the local network discovery list. |
| `mcmake.sh` | **CREATOR:** Provisions new server instances and downloads `server.jar` to `/opt/minecraft/jars`. |

---

## 4. Systemd & Security (system/ directory)
This project includes pre-configured systemd units and SELinux policy sources to ensure services run with the least privilege necessary.

### Services & Timers
* `mcserver@.service`: The main server instance template.
* `mcannounce@.service`: Handles LAN discovery broadcasts (utilizes `level-name` for MOTD).
* `mc-monitor.service/timer`: Drives the `mcrecover.sh` health checks every 2 minutes.

### SELinux Installation
On systems with SELinux (Fedora/RHEL/CentOS), you must allow `init` (systemd) to execute `screen` and manage pseudo-terminals. To avoid installing unverified binary modules, compile the provided `.te` file:

```bash
cd system/
checkmodule -M -m -o init-screen.mod init-screen.te
semodule_package -o init-screen.pp -m init-screen.mod
sudo semodule -i init-screen.pp
```

---

## 5. Directory Structure
The framework expects the following layout under `/opt/minecraft/`. Empty directories are preserved in this repo via `.gitkeep` files.

```text
/opt/minecraft/
├── bin/                # Management, Health, and Announcement scripts
├── jars/               # Master server.jar files (managed by mcmake)
├── system/             # Systemd units and SELinux policy source (.te)
├── instances/          # Root for all server data
│   └── <name>/         # Individual instance folder
│       ├── server.properties
│       ├── server.env  # Optional: Define MEMORY=4096M
│       └── logs/       # latest.log is monitored for health checks
└── README.md

---

## License
Copyright © 2026 **Karl Hastings** <karl@passkeysec.com>

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the `LICENSE` file for the full text.
