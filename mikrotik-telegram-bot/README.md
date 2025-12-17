# MikroTik Telegram Bot

A comprehensive Telegram bot for MikroTik RouterOS that provides bidirectional communication, system monitoring, automated notifications, and backup management.

## Features

### 🤖 Interactive Command Execution
- Execute RouterOS commands remotely via Telegram
- Syntax validation before execution
- Real-time output delivery (up to 4096 characters)
- Reply-to-message support for context
- Multi-device support with group activation

### 📊 System Monitoring
- **CPU Utilization**: Automatic alerts when exceeding 75%
- **RAM Usage**: Warnings at 80% threshold
- **Interface Statistics**: Traffic monitoring and error detection
- **Temperature & Voltage**: Hardware health monitoring
- **Trend Analysis**: 5-point moving average for accurate alerts

### 💾 Backup Management
- Scheduled automatic backups
- On-demand backup via `/backup now` command
- Direct backup file delivery to Telegram
- Automatic rotation policy
- Configuration export support

### 🎯 User-Friendly Commands
- `/help` - List all available commands
- `/status` - System overview and health check
- `/backup [now]` - Backup management
- `/reboot [confirm]` - Safe reboot with confirmation
- `/update [check|install]` - RouterOS update management
- `/interfaces` - Interface status and statistics
- `/dhcp` - DHCP leases overview
- `/logs [filter]` - Recent system logs
- `/traffic [interface]` - Traffic statistics

### 🔒 Security Features
- Trusted user whitelist
- Input validation and sanitization
- Rate limiting per user
- Command audit logging
- Secure token storage
- Optional 2FA for critical commands

## Quick Start

### Prerequisites
- MikroTik RouterOS 7.15 or higher
- Internet connectivity on the router
- Telegram account

### Super Quick Install (15 minutes)

Follow our [Quick Start Guide](QUICKSTART.md) for fastest setup!

### Standard Installation

1. **Create your Telegram bot**
   - Follow the [Telegram Bot Setup Guide](setup/telegram-setup.md)
   - Save your bot token and chat ID

2. **Upload scripts to RouterOS**
   - Upload all `.rsc` files from the `scripts/` directory
   - Import them via Terminal or drag-and-drop in WinBox

3. **Configure the bot**
   - Edit `bot-config.rsc` with your bot token and chat ID
   - Add trusted user IDs
   - Adjust monitoring thresholds as needed

4. **Automated Deployment (Recommended)**
   ```routeros
   /system/script/run deploy
   ```
   
   **Or Manual Setup:**
   ```routeros
   /system/script/run bot-config
   /system/script/run bot-core
   ```

5. **Verify Installation**
   ```routeros
   /system/script/run verify-installation
   ```

6. **Test the bot**
   - Send `/help` to your bot in Telegram
   - You should receive a list of available commands

**Having issues?** Run the troubleshooting script:
```routeros
/system/script/run troubleshoot
```

## Architecture

```
mikrotik-telegram-bot/
├── scripts/
│   ├── bot-core.rsc                    # Main bot logic and command processing
│   ├── bot-config.rsc                  # Configuration template
│   ├── deploy.rsc                      # Automated deployment script ⭐ NEW
│   ├── verify-installation.rsc         # Installation verification ⭐ NEW
│   ├── troubleshoot.rsc                # Automated troubleshooting ⭐ NEW
│   └── modules/
│       ├── monitoring.rsc              # System monitoring and alerts
│       ├── backup.rsc                  # Backup management
│       ├── custom-commands.rsc         # Custom command handlers
│       └── wireless-monitoring.rsc     # Wireless monitoring ⭐ NEW
├── setup/
│   ├── installation.md                 # Detailed installation guide
│   ├── telegram-setup.md               # Telegram bot creation walkthrough
│   └── security-hardening.md           # Security best practices ⭐ NEW
├── examples/
│   └── usage-examples.md               # Usage examples and scenarios
├── README.md                           # Project overview
├── QUICKSTART.md                       # 15-minute setup guide ⭐ NEW
├── FAQ.md                              # Frequently asked questions ⭐ NEW
├── PERFORMANCE.md                      # Performance optimization ⭐ NEW
├── CONTRIBUTING.md                     # Contribution guidelines
├── CHANGELOG.md                        # Version history
└── LICENSE                             # GPL-3.0 license
```

## Configuration

Edit `scripts/bot-config.rsc` to customize your bot:

```routeros
# Telegram Bot Configuration
:global TelegramTokenId "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
:global TelegramChatId "987654321"
:global TelegramChatIdsTrusted ({
  987654321;        # Your Telegram user ID
  "@yourusername"   # Or your username
})

# Monitoring Thresholds
:global MonitorCPUThreshold 75
:global MonitorRAMThreshold 80
:global MonitorTempThreshold 60
:global MonitorDiskThreshold 90

# Backup Settings
:global BackupRetention 7        # Keep last 7 backups
:global BackupAutoSend true      # Send backup files to Telegram

# Feature Toggles
:global EnableAutoMonitoring true
:global MonitoringInterval "5m"
:global EnableAutoBackup true
```

## Usage Examples

### Basic Commands

**Get system status:**
```
/status
```

**Check interfaces:**
```
/interfaces
```

**View DHCP leases:**
```
/dhcp
```

### Advanced Usage

**Execute custom RouterOS command:**
```
! YourRouterName
/ip address print
```

**Create on-demand backup:**
```
/backup now
```

**Check for updates:**
```
/update check
```

**Safe reboot with confirmation:**
```
/reboot confirm
```

### Multi-Device Management

**Activate all devices:**
```
! @all
/system resource print
```

**Activate specific device:**
```
! RouterName
/interface print stats
```

For more examples, see [Usage Examples](examples/usage-examples.md).

## Security Best Practices

1. **Whitelist Users Only**: Add only trusted user IDs to `TelegramChatIdsTrusted`
2. **Use Private Chats**: Avoid adding the bot to public groups
3. **Secure Your Token**: Never share your bot token publicly
4. **Regular Audits**: Review command logs regularly
5. **Network Isolation**: Consider firewall rules for Telegram API access
6. **Update Regularly**: Keep RouterOS and scripts up to date

## Troubleshooting

### Quick Diagnosis

**Automated Troubleshooting (Recommended):**
```routeros
/system/script/run troubleshoot
```

This script will:
- Check all configurations
- Verify connectivity
- Test certificates
- Identify common issues
- Provide specific recommendations

### Manual Troubleshooting

#### Bot doesn't respond
```routeros
# 1. Verify installation
/system/script/run verify-installation

# 2. Check scheduler
/system/scheduler/print where name="telegram-bot"

# 3. Test connectivity
/tool/fetch url=https://api.telegram.org mode=https

# 4. Check certificate
/certificate print where common-name~"Go Daddy"

# 5. Review logs
/log/print where topics~"script"
```

#### Commands fail to execute
- Verify you're in the trusted users list
- Check syntax of your command
- Review logs: `/log/print where topics~"script"`
- Check script policies: `/system/script print detail where name="bot-core"`

#### Monitoring alerts not working
- Verify monitoring module is scheduled
- Check thresholds in `bot-config.rsc`
- Ensure notifications are enabled
- Run manually: `/system/script/run modules/monitoring`

#### Backup files not received
- Check router storage space
- Verify Telegram API connectivity
- Check file size (Telegram has 50MB limit)
- Run manually: `/system/script/run modules/backup`

### Resources

- **FAQ**: [Frequently Asked Questions](FAQ.md)
- **Detailed Guide**: [Installation Guide](setup/installation.md)
- **Security**: [Security Hardening Guide](setup/security-hardening.md)
- **Performance**: [Performance Optimization](PERFORMANCE.md)

## Contributing

Contributions are welcome! This project is based on the excellent [RouterOS Scripts](https://github.com/eworm-de/routeros-scripts) by Christian Hesse.

### How to Contribute
1. Fork the repository
2. Create a feature branch
3. Test your changes on a RouterOS device
4. Submit a pull request

## Credits

This project is built upon and inspired by:
- [RouterOS Scripts](https://github.com/eworm-de/routeros-scripts) by eworm-de
- MikroTik RouterOS documentation
- Telegram Bot API

Special thanks to Christian Hesse for the excellent foundation scripts.

## License

GNU General Public License v3.0

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Always test in a non-production environment first.

## Support

- **Documentation**: Check the [setup](setup/) and [examples](examples/) directories
- **Issues**: Report bugs via GitHub issues
- **Telegram**: Join the RouterOS Scripts community [@routeros_scripts](https://t.me/routeros_scripts)

## Changelog

### v1.0.0 (Initial Release)
- Interactive command execution via Telegram
- System monitoring with automatic alerts
- Backup management with Telegram delivery
- User-friendly command aliases
- Multi-device support
- Comprehensive documentation

---

**Made with ❤️ for the MikroTik community**

