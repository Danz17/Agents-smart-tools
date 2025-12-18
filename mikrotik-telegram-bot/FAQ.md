# Frequently Asked Questions (FAQ)

Common questions and answers about the MikroTik Telegram Bot.

## General Questions

### What is this project?

The MikroTik Telegram Bot is a comprehensive solution for managing and monitoring your MikroTik router via Telegram. It allows you to:
- Execute RouterOS commands remotely
- Receive automatic monitoring alerts
- Create and manage backups
- Check system status on-demand
- Manage multiple routers from one interface

### Is it free?

Yes! This project is open-source and licensed under GPL-3.0. It's completely free to use, modify, and distribute.

### What RouterOS version do I need?

RouterOS 7.15 or higher is required. Most features work on 7.13+, but 7.15 is recommended for full compatibility.

### Does it work on all MikroTik devices?

Yes! It works on:
- RouterBOARD devices (RB series)
- Cloud Core Routers (CCR)
- Cloud Router Switches (CRS)
- Cloud Hosted Router (CHR)
- Any device running RouterOS 7.15+

### How much storage/RAM does it need?

**Minimum:**
- 16MB free storage
- 32MB RAM

**Recommended:**
- 50MB free storage (for backups)
- 64MB+ RAM

### Does it require internet access?

Yes, the router needs internet access to communicate with Telegram's API servers. However, commands are processed locally on the router.

## Installation & Setup

### How long does installation take?

Following the [QUICKSTART.md](QUICKSTART.md) guide, installation takes about 15 minutes:
- 5 minutes: Create Telegram bot
- 3 minutes: Upload scripts
- 3 minutes: Configuration
- 2 minutes: Initialize & setup schedulers
- 2 minutes: Testing

### Can I install without WinBox?

Yes! You can use:
- SSH/Terminal (copy-paste scripts)
- FTP/SFTP (upload files)
- Web interface (upload via Files section)
- Serial console (for direct access)

### Do I need to open any firewall ports?

No! The bot makes **outbound** connections to Telegram's API. No inbound ports need to be opened. This is more secure than traditional remote management.

### Can I use an existing Telegram bot?

Yes, if you already have a Telegram bot, you can reuse its token. Just update the `TelegramTokenId` in the configuration.

### How do I get my Chat ID?

Multiple methods:
1. Use `@userinfobot` in Telegram
2. Use `@RawDataBot` in Telegram
3. Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Use the `$GetTelegramChatId` function in RouterOS

See [Telegram Setup Guide](setup/telegram-setup.md) for details.

## Usage Questions

### How do I activate the bot?

Send `! RouterName` (exclamation mark, space, your router's identity) to activate. Then you can send commands. Send `!` alone to deactivate.

### Why isn't my router responding?

Common reasons:
1. **Not activated**: Send `! RouterName` first
2. **Wrong identity**: Check with `/system identity print`
3. **Scheduler not running**: Check `/system scheduler print`
4. **Certificate missing**: Install Go Daddy G2 certificate
5. **Internet issue**: Test with `/ping 8.8.8.8`

### Can multiple users control the bot?

Yes! Add their user IDs to `TelegramChatIdsTrusted`:
```routeros
:global TelegramChatIdsTrusted ({
  123456789;    # User 1
  987654321;    # User 2
  "@username"   # User 3 (by username)
})
```

### How do I run RouterOS commands?

1. Activate your router: `! RouterName`
2. Send any RouterOS command: `/ip address print`
3. Receive output in Telegram

### What if command output is too long?

Telegram has a 4096 character limit. If output exceeds this:
- The message is truncated
- A warning is added
- Use filters to reduce output: `/ip address print where interface=ether1`

### Can I use the bot in a Telegram group?

Yes! Add your bot to a group and make it an admin (needed for read access). Use the group's chat ID (which will be negative, like `-123456789`).

## Security Questions

### Is it secure?

Yes, with proper configuration:
- ✅ User whitelist (only trusted users)
- ✅ All commands logged
- ✅ Syntax validation before execution
- ✅ HTTPS encrypted communication
- ✅ No inbound ports needed
- ✅ Confirmation for dangerous commands

**Important**: Keep your bot token secret!

### What if someone gets my bot token?

If your token is compromised:
1. Revoke it immediately via BotFather: `/revoke`
2. Create a new bot with new token
3. Update your configuration
4. Review logs for unauthorized access

### Can I restrict certain commands?

Yes! Enable command whitelist:
```routeros
:global EnableCommandWhitelist true
:global CommandWhitelist ({
  "/ip address print";
  "/interface print";
  "/system resource print"
})
```

### Should I use the bot over public internet?

The bot uses HTTPS encryption, so communication is secure. However:
- ✅ Use strong router passwords
- ✅ Keep token secret
- ✅ Whitelist trusted users only
- ✅ Enable command logging
- ✅ Review logs regularly

### What about 2FA?

Currently not built-in, but you can:
- Implement confirmation for critical commands (built-in)
- Use Telegram's 2FA for your account
- Monitor command logs
- Use time-based restrictions in schedulers

## Monitoring & Alerts

### How often does monitoring run?

Default: Every 5 minutes. Configurable in the scheduler:
```routeros
/system scheduler set system-monitoring interval=10m
```

### What triggers an alert?

Alerts trigger when:
- CPU > 75% (configurable)
- RAM > 80% (configurable)
- Disk > 90% (configurable)
- Temperature > threshold
- Voltage out of range
- Interface goes down
- System reboots

### How do I change alert thresholds?

Edit in `bot-config.rsc`:
```routeros
:global MonitorCPUThreshold 75      # Percent
:global MonitorRAMThreshold 80      # Percent
:global MonitorDiskThreshold 90     # Percent
:global MonitorTempThreshold 60     # Celsius
```

### Can I disable monitoring?

Yes:
```routeros
:global EnableAutoMonitoring false
```

Or remove the scheduler:
```routeros
/system scheduler remove system-monitoring
```

### Do I get recovery notifications?

Yes! When values return to normal, you receive a recovery notification.

### Can I monitor specific interfaces only?

Yes:
```routeros
:global MonitorInterfaces "ether1,ether2,bridge"
```

## Backup Questions

### Where are backups stored?

Backups are stored on the router in the `/file` directory. They're named with identity and timestamp:
```
RouterName-241217-1430.backup
RouterName-241217-1430-config.rsc
```

### How do I download backups?

Methods:
1. **FTP/SFTP**: Enable and connect to download
2. **WinBox**: Use Files section
3. **Cloud**: Enable `BackupToCloud` for MikroTik Cloud
4. **Manual**: Use `/export` to create downloadable config

### Can backups be sent to Telegram?

Telegram has a 50MB file size limit. The bot:
- Notifies when backup is created
- Shows file size
- Provides download instructions
- (Direct upload has RouterOS fetch limitations)

### How often do backups run?

Default: Daily at 2 AM. Configurable:
```routeros
/system scheduler set auto-backup start-time="03:00:00" interval=1d
```

### How many backups are kept?

Default: 7 backups (1 week). Configurable:
```routeros
:global BackupRetention 14  # Keep 14 backups
```

### Are backups encrypted?

Yes, if you set a password:
```routeros
:global BackupPassword "YourStrongPassword"
```

Leave empty for no encryption.

### Can I create manual backups?

Yes! Send `/backup now` to your bot.

### How do I restore a backup?

1. Download the backup file
2. Upload to router
3. `/system backup load name=backup-file.backup`
4. Router will reboot and restore

## Multi-Device Management

### Can I manage multiple routers?

Yes! Install the bot on each router and use group activation:
```
! @all            # Activate all routers
! @home          # Activate home group
! @office        # Activate office group
```

### How do I set up groups?

On each router, configure:
```routeros
# Home router
:global TelegramChatGroups "home,all"

# Office router
:global TelegramChatGroups "office,all"
```

### Will all routers respond at once?

Yes, when using group activation. Each router sends a separate message.

### Can I have different chat IDs per router?

Yes! Each router can have its own configuration with different chat IDs and trusted users.

### How do I identify which router responded?

Each message starts with `[RouterName]` using the router's identity.

## Troubleshooting

### "Certificate download failed" error

Install certificate manually:
```routeros
/tool fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" \
  mode=https dst-path=godaddy.pem
/certificate import file-name=godaddy.pem passphrase=""
```

### Bot was working, now it's not

Check:
1. Internet connectivity: `/ping 8.8.8.8`
2. Scheduler status: `/system scheduler print where name="telegram-bot"`
3. Logs: `/log print where topics~"script"`
4. Certificate: `/certificate print`
5. Configuration: `:put $TelegramTokenId`

### Commands execute but no output

Check script policies:
```routeros
/system script set bot-core policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
```

### High CPU usage

Reduce polling frequency:
```routeros
/system scheduler set telegram-bot interval=60s
```

Reduce monitoring frequency:
```routeros
/system scheduler set system-monitoring interval=10m
```

### "Global config not ready" error

Run configuration first:
```routeros
/system script run bot-config
```

Or re-import:
```routeros
/import bot-config.rsc
```

### Messages are queued but not sent

This happens when Telegram API is temporarily unreachable. Messages are automatically sent when connectivity returns. To manually flush:
```routeros
# Check queue
:put $TelegramQueue

# Queue clears automatically when connection restored
```

## Performance & Limitations

### Does the bot affect router performance?

Minimal impact:
- Polling uses ~1% CPU every 30 seconds
- Monitoring uses ~2% CPU every 5 minutes
- Memory usage: ~5-10MB
- Bandwidth: ~1-5 KB per poll

### What's the maximum message length?

Telegram limits messages to 4096 characters. Longer outputs are truncated with a warning.

### Can I reduce bandwidth usage?

Yes:
- Increase polling interval (30s → 60s)
- Disable unnecessary monitoring
- Use filters on commands to reduce output

### What's the command timeout?

Default: 20 seconds. Commands exceeding this continue in background but output may be incomplete. Configurable:
```routeros
:global TelegramChatRunTime "30s"
```

### How many commands can I send per minute?

No hard limit, but Telegram rate-limits API calls. Recommended: <30 commands/minute.

## Advanced Usage

### Can I create custom commands?

Yes! Add to `bot-config.rsc`:
```routeros
:global CustomCommands ({
  "wifi"="/interface wireless print";
  "wan"="/ip address print where interface=ether1";
  "cpu"="/system resource cpu print"
})
```

Then use: `/wifi`, `/wan`, `/cpu`

### Can I schedule commands?

Yes! Create a scheduler:
```routeros
/system scheduler add name="daily-report" interval=1d start-time="08:00:00" \
  on-event=":global SendTelegram2; \$SendTelegram2 ({subject=\"Daily Report\"; message=[/system resource get uptime]})"
```

### Can I integrate with other systems?

Yes! The bot can:
- Send notifications from custom scripts
- Trigger actions based on external events
- Export data for external monitoring
- Integrate with SNMP/syslog

### Can I use webhooks instead of polling?

Not currently implemented, but it's on the roadmap. Polling is simpler and works behind NAT.

### Can I add custom monitoring metrics?

Yes! Create custom health check scripts in `/system script` and call them from the monitoring module.

## Getting Help

### Where can I get support?

1. **Documentation**: Check [setup/](setup/) and [examples/](examples/)
2. **FAQ**: This document
3. **Troubleshooting**: [installation.md](setup/installation.md#troubleshooting)
4. **Community**: [@routeros_scripts](https://t.me/routeros_scripts)
5. **GitHub Issues**: Report bugs and request features

### How do I report a bug?

Open a GitHub issue with:
- RouterOS version
- Bot version
- Clear description
- Steps to reproduce
- Log entries
- Expected vs actual behavior

See [CONTRIBUTING.md](CONTRIBUTING.md) for template.

### How can I contribute?

Contributions welcome!
- Report bugs
- Suggest features
- Improve documentation
- Submit code
- Share usage examples

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Is there a roadmap?

Yes! See [CHANGELOG.md](CHANGELOG.md) for planned features:
- Direct file upload to Telegram
- Interactive button menus
- Webhook support
- 2FA integration
- Traffic analysis
- Web dashboard

## Legal & Licensing

### What's the license?

GPL-3.0 - Free and open source. You can:
- ✅ Use commercially
- ✅ Modify
- ✅ Distribute
- ✅ Use privately

Requirements:
- ⚠️ Disclose source
- ⚠️ License and copyright notice
- ⚠️ Same license
- ⚠️ State changes

### Can I use this commercially?

Yes! GPL-3.0 allows commercial use. No fees or restrictions.

### Who maintains this project?

This is a community project based on the excellent work by Christian Hesse (eworm-de). Contributions from the community are welcome.

### How do I cite this project?

```
MikroTik Telegram Bot
Based on RouterOS Scripts by Christian Hesse
https://github.com/yourusername/mikrotik-telegram-bot
License: GPL-3.0
```

---

**Still have questions?** Ask in the [Telegram Group](https://t.me/routeros_scripts) or open a [GitHub Discussion](https://github.com/Danz17/Agents-smart-tools/discussions).

