<div align="center">

```
 ____  _   _ _____ _   _ _____  __
|  _ \| | | | ____| \ | |_ _\ \/ /
| |_) | |_| |  _| |  \| || | \  /
|  __/|  _  | |___| |\  || | /  \
|_|   |_| |_|_____|_| \_|___/_/\_\
```

# TxMTC
### Telegram x MikroTik Tunnel Controller Sub-Agent

![RouterOS](https://img.shields.io/badge/RouterOS-7.15+-red)
![Telegram](https://img.shields.io/badge/Telegram-Bot%20API-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

**Control your MikroTik router via Telegram with style**

*Crafted with love & frustration by* **P̷h̷e̷n̷i̷x̷**

</div>

---

## Features

### Remote Control
- Execute RouterOS commands via Telegram
- Syntax validation before execution
- Real-time output delivery
- Multi-device support with group activation

### System Monitoring
- CPU, RAM, Disk usage alerts
- Temperature & Voltage monitoring
- Interface statistics & error detection
- Wireless client tracking
- Daily automated status reports

### Backup Management
- Scheduled automatic backups
- On-demand backup via `/backup now`
- Configurable retention policy
- Telegram notifications

### Security
- Trusted user whitelist
- Rate limiting (configurable)
- Command confirmation flow
- User blocking after failed attempts
- Audit logging

---

## Quick Install

### Prerequisites
- MikroTik RouterOS 7.15+
- Internet connectivity
- Telegram account

### One-Line Install
```routeros
/tool fetch url="https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts/update-scripts.rsc" dst-path=update-scripts.rsc; /import update-scripts.rsc
```

### Configure
```routeros
:global TelegramTokenId "YOUR_BOT_TOKEN"
:global TelegramChatId "YOUR_CHAT_ID"
:global TelegramChatIdsTrusted "YOUR_CHAT_ID"
:global BotConfigReady true
/system script run bot-config
```

### Test
Send `?` to your bot in Telegram!

---

## Commands

| Command | Description |
|---------|-------------|
| `?` | Check bot status |
| `/help` | Show all commands |
| `/status` | System overview |
| `/interfaces` | Interface stats |
| `/dhcp` | DHCP leases |
| `/logs` | Recent logs |
| `/backup now` | Create backup |
| `/wireless` | WiFi clients |
| `! RouterName` | Activate device |
| `! @all` | Activate all |

---

## Project Structure

```
mikrotik-telegram-bot/
├── scripts/
│   ├── bot-config.rsc           # Configuration
│   ├── bot-core.rsc             # Main bot logic
│   ├── update-scripts.rsc       # Installer/updater
│   ├── deploy.rsc               # Deployment script
│   └── modules/
│       ├── telegram-api.rsc     # Telegram API
│       ├── shared-functions.rsc # Utilities
│       ├── security.rsc         # Security features
│       ├── monitoring.rsc       # System monitoring
│       ├── backup.rsc           # Backup management
│       ├── wireless-monitoring.rsc
│       ├── daily-summary.rsc
│       └── custom-commands.rsc
├── setup/
│   ├── installation.md
│   ├── telegram-setup.md
│   └── security-hardening.md
├── README.md
├── QUICKSTART.md
├── FAQ.md
└── CHANGELOG.md
```

---

## Configuration

```routeros
# Credentials (REQUIRED)
:global TelegramTokenId "YOUR_BOT_TOKEN"
:global TelegramChatId "YOUR_CHAT_ID"
:global TelegramChatIdsTrusted "YOUR_CHAT_ID"

# Monitoring
:global MonitorCPUThreshold 75
:global MonitorRAMThreshold 80
:global MonitorDiskThreshold 90

# Security
:global CommandRateLimit 10
:global RequireConfirmation true
:global MaxFailedAttempts 5
:global BlockDuration 30

# Features
:global EnableAutoMonitoring true
:global SendDailySummary true
```

---

## Roadmap

### v2.1 (Next)
- [ ] Auto-updater scheduler
- [ ] `/update` command
- [ ] Version check on startup

### v2.2
- [ ] BotFather setup wizard
- [ ] Hotspot monitoring module
- [ ] Layer 2 bridge/VLAN control

### v3.0
- [ ] Mobile WebApp for setup
- [ ] Multi-router management
- [ ] Traffic graph images

---

## Troubleshooting

```routeros
# Automated troubleshoot
/system script run troubleshoot

# Verify installation
/system script run verify-installation

# Check logs
/log print where topics~"script"
```

| Issue | Solution |
|-------|----------|
| No response | Check scheduler: `/system scheduler print` |
| SSL error | Import CA certs (auto-done on install) |
| Rate limited | Wait 1 min or increase `CommandRateLimit` |

---

## Credits

- [eworm-de/routeros-scripts](https://github.com/eworm-de/routeros-scripts)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- MikroTik RouterOS Documentation

---

## License

GNU General Public License v3.0

---

<div align="center">

**TxMTC** - *Crafted with love & frustration by* **P̷h̷e̷n̷i̷x̷**

</div>
