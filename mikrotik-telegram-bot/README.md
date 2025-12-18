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
- **CPU Utilization**: Automatic alerts when exceeding threshold
- **RAM Usage**: Warnings at configured threshold
- **Disk Usage**: Storage monitoring
- **Interface Statistics**: Traffic monitoring and error detection
- **Temperature & Voltage**: Hardware health monitoring
- **Wireless Clients**: WiFi client tracking and signal monitoring
- **Daily Summary**: Automated daily status reports

### 💾 Backup Management
- Scheduled automatic backups
- On-demand backup via `/backup now` command
- Automatic rotation policy (configurable retention)
- Configuration export support
- Telegram notifications on completion

### 🎯 User-Friendly Commands
- `/help` - List all available commands
- `/status` - System overview and health check
- `/backup [now|list]` - Backup management
- `/interfaces` - Interface status and statistics
- `/dhcp` - DHCP leases overview
- `/logs [filter]` - Recent system logs
- `/wireless` - Wireless client status
- `/update [check]` - RouterOS update check

### 🔒 Security Features
- **Trusted User Whitelist**: Only authorized users can control the bot
- **Rate Limiting**: Configurable commands per minute per user
- **Command Confirmation**: Dangerous commands require confirmation code
- **Command Whitelist**: Optional restriction to approved commands only
- **User Blocking**: Automatic blocking after failed attempts
- **Audit Logging**: All commands logged to system log
- **Input Validation**: Syntax validation before execution

## Quick Start

### Prerequisites
- MikroTik RouterOS 7.15 or higher
- Internet connectivity on the router
- Telegram account

### Installation (5 Steps)

1. **Create your Telegram bot**
   - Message [@BotFather](https://t.me/BotFather) on Telegram
   - Send `/newbot` and follow the prompts
   - Save your bot token

2. **Get your Chat ID**
   ```routeros
   :global TelegramTokenId "YOUR_BOT_TOKEN"
   $GetTelegramChatId
   ```

3. **Upload scripts to RouterOS**
   - Upload all `.rsc` files from the `scripts/` directory

4. **Configure and deploy**
   ```routeros
   :global TelegramTokenId "YOUR_BOT_TOKEN"
   :global TelegramChatId "YOUR_CHAT_ID"
   :global TelegramChatIdsTrusted "YOUR_CHAT_ID"
   :global BotConfigReady true
   /import deploy.rsc
   ```

5. **Test the bot**
   - Send `?` to your bot in Telegram
   - You should receive a greeting message

**Having issues?** Run the troubleshooting script:
```routeros
/system script run troubleshoot
```

## Project Structure

```
mikrotik-telegram-bot/
├── scripts/
│   ├── bot-config.rsc           # Configuration template
│   ├── bot-core.rsc             # Main bot logic and command processing
│   ├── deploy.rsc               # Automated deployment script
│   ├── verify-installation.rsc  # Installation verification
│   ├── troubleshoot.rsc         # Automated troubleshooting
│   └── modules/
│       ├── monitoring.rsc       # System monitoring and alerts
│       ├── backup.rsc           # Backup management
│       ├── custom-commands.rsc  # Custom command handlers
│       ├── wireless-monitoring.rsc # Wireless monitoring
│       └── daily-summary.rsc    # Daily status reports
├── setup/
│   ├── installation.md          # Detailed installation guide
│   ├── telegram-setup.md        # Telegram bot creation walkthrough
│   └── security-hardening.md    # Security best practices
├── examples/
│   └── usage-examples.md        # Usage examples and scenarios
├── README.md                    # This file
├── QUICKSTART.md                # Quick setup guide
├── FAQ.md                       # Frequently asked questions
├── CONTRIBUTING.md              # Contribution guidelines
├── CHANGELOG.md                 # Version history
└── LICENSE                      # GPL-3.0 license
```

## Configuration

Edit `scripts/bot-config.rsc` or set variables directly:

```routeros
# Telegram Bot Credentials (REQUIRED)
:global TelegramTokenId "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
:global TelegramChatId "987654321"
:global TelegramChatIdsTrusted "987654321"

# Monitoring Thresholds
:global MonitorCPUThreshold 75       # CPU % alert threshold
:global MonitorRAMThreshold 80       # RAM % alert threshold
:global MonitorDiskThreshold 90      # Disk % alert threshold
:global MonitorTempThreshold 60      # Temperature °C threshold

# Backup Settings
:global EnableAutoBackup true
:global BackupRetention 7            # Keep last 7 backups

# Security Settings
:global CommandRateLimit 10          # Commands per minute per user
:global RequireConfirmation true     # Require confirmation for dangerous commands
:global EnableCommandWhitelist false # Restrict to whitelisted commands only
:global MaxFailedAttempts 5          # Block after N failed attempts
:global BlockDuration 30             # Block duration in minutes

# Feature Toggles
:global EnableAutoMonitoring true
:global SendDailySummary true
:global DailySummaryTime "08:00"
```

## Usage Examples

### Basic Commands

```
?                    # Check bot status
/help                # Show available commands
/status              # System status
/interfaces          # Interface statistics
/dhcp                # DHCP leases
/logs                # Recent logs
/backup now          # Create backup
```

### Advanced Usage

**Activate device and execute command:**
```
! RouterName
/ip address print
```

**Multi-device activation:**
```
! @all
/system resource print
```

### Confirmation Flow

Dangerous commands require confirmation:
```
You: /system reboot

Bot: ⚠️ Confirmation Required
     To confirm, send: CONFIRM XK92MN

You: CONFIRM XK92MN

Bot: 🔄 Rebooting router...
```

## Troubleshooting

### Quick Diagnosis

```routeros
# Automated troubleshooting
/system script run troubleshoot

# Verify installation
/system script run verify-installation

# Manual bot test
/system script run bot-core
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Bot doesn't respond | Check scheduler: `/system scheduler print where name~"telegram"` |
| Certificate error | Import cert: `/tool fetch url=https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem` |
| Commands fail | Check trusted list, verify syntax, review logs |
| Rate limited | Wait 1 minute or increase `CommandRateLimit` |

### Resources

- **FAQ**: [Frequently Asked Questions](FAQ.md)
- **Installation**: [Detailed Guide](setup/installation.md)
- **Security**: [Hardening Guide](setup/security-hardening.md)
- **Examples**: [Usage Examples](examples/usage-examples.md)

## Security Best Practices

1. **Whitelist Users**: Only add trusted user IDs
2. **Private Chats**: Avoid adding bot to public groups
3. **Secure Token**: Never share your bot token
4. **Enable Confirmation**: Keep `RequireConfirmation` enabled
5. **Review Logs**: Check `/log print where topics~"script"` regularly
6. **Update Regularly**: Keep RouterOS and scripts current

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Credits

Built upon and inspired by:
- [RouterOS Scripts](https://github.com/eworm-de/routeros-scripts) by eworm-de
- MikroTik RouterOS documentation
- Telegram Bot API

## License

GNU General Public License v3.0 - See [LICENSE](LICENSE) for details.

## Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Always test in a non-production environment first.

---

**Made with ❤️ for the MikroTik community**
