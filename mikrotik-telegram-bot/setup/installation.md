# Installation Guide

Complete step-by-step guide to install and configure the MikroTik Telegram Bot on your RouterOS device.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Preparation](#preparation)
3. [Upload Scripts](#upload-scripts)
4. [Configuration](#configuration)
5. [Initialize the Bot](#initialize-the-bot)
6. [Set Up Schedulers](#set-up-schedulers)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements
- MikroTik RouterOS device (RouterBoard, CCR, CRS, CHR)
- Minimum 32MB RAM (64MB+ recommended)
- At least 5MB free storage

### Software Requirements
- RouterOS version **7.15 or higher**
- Internet connectivity (for Telegram API access)
- HTTPS certificate support (built into RouterOS)

### Telegram Requirements
- Telegram account
- Bot token (from BotFather)
- Your chat ID

**If you haven't created your bot yet**, follow the [Telegram Bot Setup Guide](telegram-setup.md) first.

## Preparation

### Step 1: Check RouterOS Version

Connect to your router via Terminal or WinBox and check the version:

```routeros
/system resource print
```

Look for the `version` field. If it's below 7.15, update RouterOS first:

```routeros
/system package update check-for-updates
/system package update download
/system reboot
```

### Step 2: Verify Internet Connectivity

Test HTTPS connectivity to Telegram:

```routeros
/tool fetch url="https://api.telegram.org" mode=https
```

You should see output without errors. If you get certificate errors, proceed to download the required certificate.

### Step 3: Install Required Certificate

Download and import the Go Daddy Root Certificate (required for Telegram API):

```routeros
/tool fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" \
  mode=https dst-path=godaddy-g2.pem

/certificate import file-name=godaddy-g2.pem passphrase=""
```

Verify the certificate is installed:

```routeros
/certificate print where common-name~"Go Daddy"
```

## Upload Scripts

You have several methods to upload the scripts to your RouterOS device:

### Method 1: Via WinBox (Windows/Wine)

1. Open WinBox and connect to your router
2. Click **Files** in the left menu
3. Drag and drop all `.rsc` files from the `scripts/` folder
4. Wait for upload to complete

### Method 2: Via FTP

1. Enable FTP on your router (temporarily):
   ```routeros
   /ip service set ftp disabled=no
   ```

2. Upload files using an FTP client (FileZilla, WinSCP, etc.):
   - Host: Your router IP
   - Username: admin (or your admin user)
   - Password: Your router password
   - Upload all `.rsc` files

3. Disable FTP after upload:
   ```routeros
   /ip service set ftp disabled=yes
   ```

### Method 3: Via SFTP (SSH)

1. Enable SSH if not already enabled:
   ```routeros
   /ip service set ssh disabled=no port=22
   ```

2. Upload using SFTP:
   ```bash
   sftp admin@your-router-ip
   put scripts/bot-config.rsc
   put scripts/bot-core.rsc
   put scripts/modules/monitoring.rsc
   put scripts/modules/backup.rsc
   put scripts/modules/custom-commands.rsc
   ```

### Method 4: Copy-Paste via Terminal

For each script file:

1. Open the file in a text editor
2. Copy the entire contents
3. In RouterOS terminal, type:
   ```routeros
   /file print file=bot-config
   ```
4. Open the file for editing:
   ```routeros
   /file edit bot-config.rsc
   ```
5. Paste the contents and save (Ctrl+O, Ctrl+X)

Repeat for all script files.

## Configuration

### Step 1: Edit Configuration File

Edit `bot-config.rsc` with your specific settings:

```routeros
/file edit bot-config.rsc
```

Update these critical values:

```routeros
:global TelegramTokenId "YOUR_BOT_TOKEN_FROM_BOTFATHER"
:global TelegramChatId "YOUR_CHAT_ID_FROM_TELEGRAM"
:global TelegramChatIdsTrusted ({
  "YOUR_CHAT_ID_HERE";
  # Add more trusted users:
  # 987654321;
  # "@username";
})
```

**Important settings to review:**

- `Identity`: Your router name (uses system identity by default)
- `TelegramChatGroups`: Device groups (e.g., "home,all")
- `MonitorCPUThreshold`: CPU alert threshold (default: 75%)
- `MonitorRAMThreshold`: RAM alert threshold (default: 80%)
- `BackupRetention`: Number of backups to keep (default: 7)
- `EnableAutoMonitoring`: Enable automatic monitoring (default: true)
- `EnableAutoBackup`: Enable automatic backups (default: true)

Save the file when done.

### Step 2: Create Scripts in RouterOS

Import the configuration and create scripts:

```routeros
# Import configuration
/import bot-config.rsc

# Create bot core script
/system script add name=bot-core source=[/file get bot-core.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

# Create monitoring module
/system script add name=modules/monitoring source=[/file get monitoring.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

# Create backup module
/system script add name=modules/backup source=[/file get backup.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

# Create custom commands module
/system script add name=modules/custom-commands source=[/file get custom-commands.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
```

Verify scripts are created:

```routeros
/system script print
```

You should see all four scripts listed.

## Initialize the Bot

### Step 1: Load Configuration

Run the configuration script to set global variables:

```routeros
/system script run bot-config
```

Check for any errors in the log:

```routeros
/log print where topics~"script"
```

### Step 2: Test Bot Core

Run the bot core manually to ensure it works:

```routeros
/system script run bot-core
```

This should poll Telegram for updates. Check logs for success:

```routeros
/log print where message~"telegram"
```

### Step 3: Send Test Message

From Telegram, send a message to your bot:

```
?
```

The bot should respond with a greeting message. If it does, congratulations! The bot is working.

## Set Up Schedulers

Create scheduled tasks to run the bot and monitoring automatically:

### Bot Polling Scheduler

This runs every 30 seconds to check for new messages:

```routeros
/system scheduler add \
  name="telegram-bot" \
  interval=30s \
  start-time=startup \
  policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
  on-event="/system script run bot-core"
```

### System Monitoring Scheduler

This runs every 5 minutes to check system health:

```routeros
/system scheduler add \
  name="system-monitoring" \
  interval=5m \
  start-time=startup \
  policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
  on-event="/system script run modules/monitoring"
```

### Automatic Backup Scheduler

This runs daily at 2 AM to create backups:

```routeros
/system scheduler add \
  name="auto-backup" \
  interval=1d \
  start-time="02:00:00" \
  policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
  on-event="/system script run modules/backup"
```

### Verify Schedulers

Check that all schedulers are created and running:

```routeros
/system scheduler print
```

You should see all three schedulers with `next-run` times showing.

## Testing

### Test 1: Bot Response

Send to your bot in Telegram:
```
?
```

Expected response:
```
Hello [Your Name]!

Online (and active!), awaiting your commands!
```

### Test 2: Help Command

Send:
```
/help
```

Expected: List of available commands

### Test 3: Status Command

Send:
```
/status
```

Expected: System status with CPU, RAM, disk, uptime

### Test 4: Command Execution

Activate your device and run a command:
```
! YourRouterName
/system resource print
```

Expected: System resource information

### Test 5: Monitoring Alerts

If you want to test monitoring alerts (optional):

```routeros
# Temporarily lower CPU threshold to trigger alert
:global MonitorCPUThreshold 1

# Run monitoring
/system script run modules/monitoring

# Reset threshold
:global MonitorCPUThreshold 75
```

You should receive a CPU alert notification.

## Troubleshooting

### Bot doesn't respond to messages

**Check 1: Scheduler running?**
```routeros
/system scheduler print where name="telegram-bot"
```

Look for `run-count` > 0 and `next-run` showing a future time.

**Check 2: Internet connectivity?**
```routeros
/tool fetch url="https://api.telegram.org/botYOUR_TOKEN/getMe" mode=https
```

Should return bot information in JSON format.

**Check 3: Certificate installed?**
```routeros
/certificate print where common-name~"Go Daddy"
```

Should show the certificate. If not, re-install it.

**Check 4: Logs for errors?**
```routeros
/log print where topics~"script,error"
```

Look for any error messages.

### Bot token or chat ID incorrect

**Verify token:**
Visit in browser:
```
https://api.telegram.org/botYOUR_TOKEN/getMe
```

Should return bot details, not error.

**Get correct chat ID:**
```routeros
:global TelegramTokenId "YOUR_TOKEN"
:global GetTelegramChatId
$GetTelegramChatId
```

Send a message to your bot first, then run the above command.

### Commands execute but no output

**Check execution policy:**
```routeros
/system script print detail where name="bot-core"
```

Ensure policy includes: `ftp,read,write,policy,test,password,sniff,sensitive,romon`

**Update policy:**
```routeros
/system script set bot-core policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
```

### Monitoring not working

**Check if monitoring is enabled:**
```routeros
:put $EnableAutoMonitoring
```

Should return `true`. If not:
```routeros
:global EnableAutoMonitoring true
```

**Manually run monitoring:**
```routeros
/system script run modules/monitoring
```

Check logs for any errors.

### Backups not created

**Check if backup is enabled:**
```routeros
:put $EnableAutoBackup
```

**Verify scheduler:**
```routeros
/system scheduler print where name="auto-backup"
```

**Manually trigger backup:**
```routeros
/system script run modules/backup
```

Check `/file` for created backup files.

### High CPU usage from bot

**Increase polling interval:**
```routeros
/system scheduler set telegram-bot interval=60s
```

**Reduce monitoring frequency:**
```routeros
/system scheduler set system-monitoring interval=10m
```

### Certificate errors

**Download and install certificate manually:**
```routeros
/tool fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" \
  mode=https dst-path=godaddy-g2.pem

/certificate import file-name=godaddy-g2.pem passphrase=""
```

**Verify installation:**
```routeros
/certificate print where common-name="Go Daddy Root Certificate Authority - G2"
```

### Messages queued but not sent

**Flush the queue manually:**
```routeros
# Check queue
:put $TelegramQueue

# Clear queue (if needed)
:global TelegramQueue {}
```

**Check for temporary network issues:**
```routeros
/tool fetch url="https://api.telegram.org" mode=https
```

## Security Recommendations

### 1. Restrict Access

Only add trusted users to `TelegramChatIdsTrusted`:

```routeros
:global TelegramChatIdsTrusted ({
  123456789;      # Only your user ID
  # Do NOT add unknown IDs
})
```

### 2. Use Strong Router Password

```routeros
/user set admin password="your-strong-password-here"
```

### 3. Limit Services

Disable unnecessary services:

```routeros
/ip service disable telnet,ftp,www
/ip service set winbox address=192.168.0.0/16
/ip service set ssh address=192.168.0.0/16
```

### 4. Firewall Rules

Add firewall rules to restrict management access:

```routeros
/ip firewall filter add chain=input protocol=tcp dst-port=8291 \
  src-address-list=!allowed action=drop comment="Block WinBox"

/ip firewall filter add chain=input protocol=tcp dst-port=22 \
  src-address-list=!allowed action=drop comment="Block SSH"
```

### 5. Regular Updates

Keep RouterOS and scripts updated:

```routeros
/system package update check-for-updates
```

### 6. Monitor Logs

Regularly review logs for suspicious activity:

```routeros
/log print where topics~"system,critical,error"
```

## Post-Installation

### Recommended Actions

1. **Test all commands** - Try each command to ensure it works
2. **Set up backups** - Verify automatic backups are working
3. **Configure monitoring** - Adjust thresholds for your environment
4. **Document your setup** - Keep notes on your configuration
5. **Test recovery** - Practice restoring from backup

### Optional Enhancements

1. **Multiple devices** - Install on other routers and use groups
2. **Custom commands** - Add your own command aliases in `bot-config.rsc`
3. **Extended monitoring** - Add custom health checks
4. **External notifications** - Integrate with other monitoring systems

## Next Steps

- Review [Usage Examples](../examples/usage-examples.md) for common scenarios
- Join the [RouterOS Scripts Telegram Group](https://t.me/routeros_scripts) for support
- Check the [README](../README.md) for feature details

## Getting Help

If you encounter issues:

1. Check this troubleshooting section
2. Review logs: `/log print where topics~"script,error"`
3. Search existing GitHub issues
4. Ask in the Telegram community group
5. Create a new GitHub issue with:
   - RouterOS version
   - Error messages from logs
   - Configuration (with token/IDs removed)
   - Steps to reproduce

---

**Congratulations!** Your MikroTik Telegram Bot is now installed and running. 🎉

