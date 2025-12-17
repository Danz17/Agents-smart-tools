# Quick Start Guide

Get your MikroTik Telegram Bot up and running in 15 minutes!

## Prerequisites Checklist

- [ ] MikroTik router with RouterOS 7.15+
- [ ] Router has internet access
- [ ] Telegram account
- [ ] 15 minutes of time

## Step 1: Create Telegram Bot (5 minutes)

1. **Open Telegram** and search for `@BotFather`

2. **Create bot**: Send `/newbot` to BotFather

3. **Name your bot**: 
   - Bot name: `My Router Monitor`
   - Username: `my_home_router_bot` (must end with `bot`)

4. **Save your token**: You'll receive something like:
   ```
   123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   ```
   **Keep this secret!**

5. **Get your Chat ID**:
   - Send any message to your bot
   - Visit: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - Find your chat ID: `"chat":{"id":987654321`

## Step 2: Upload Scripts (3 minutes)

### Option A: Via WinBox (Easiest)

1. Open WinBox and connect to your router
2. Click **Files** menu
3. Drag and drop all 5 `.rsc` files from the `scripts/` folder:
   - `bot-config.rsc`
   - `bot-core.rsc`
   - `monitoring.rsc`
   - `backup.rsc`
   - `custom-commands.rsc`

### Option B: Via Terminal

```bash
# Using SCP (if SSH enabled)
scp scripts/*.rsc admin@your-router-ip:/
```

## Step 3: Configure (3 minutes)

1. **Connect to router terminal** (WinBox Terminal or SSH)

2. **Edit configuration**:
   ```routeros
   /file edit bot-config.rsc
   ```

3. **Update these three lines**:
   ```routeros
   :global TelegramTokenId "YOUR_TOKEN_HERE"
   :global TelegramChatId "YOUR_CHAT_ID_HERE"
   :global TelegramChatIdsTrusted ({ "YOUR_CHAT_ID_HERE"; })
   ```

4. **Save** and exit (Ctrl+O, Ctrl+X)

## Step 4: Install & Initialize (2 minutes)

Run these commands in RouterOS terminal:

```routeros
# 1. Import configuration
/import bot-config.rsc

# 2. Create scripts
/system script add name=bot-core source=[/file get bot-core.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

/system script add name=modules/monitoring source=[/file get monitoring.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

/system script add name=modules/backup source=[/file get backup.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

/system script add name=modules/custom-commands source=[/file get custom-commands.rsc contents] policy=ftp,read,write,policy,test,password,sniff,sensitive,romon

# 3. Set up schedulers
/system scheduler add name="telegram-bot" interval=30s start-time=startup policy=ftp,read,write,policy,test,password,sniff,sensitive,romon on-event="/system script run bot-core"

/system scheduler add name="system-monitoring" interval=5m start-time=startup policy=ftp,read,write,policy,test,password,sniff,sensitive,romon on-event="/system script run modules/monitoring"

/system scheduler add name="auto-backup" interval=1d start-time="02:00:00" policy=ftp,read,write,policy,test,password,sniff,sensitive,romon on-event="/system script run modules/backup"
```

## Step 5: Test (2 minutes)

1. **In Telegram, send to your bot**:
   ```
   ?
   ```

2. **You should receive**:
   ```
   🤖 Telegram Bot
   
   Hello [Your Name]!
   
   Online (and active!), awaiting your commands!
   ```

3. **Try other commands**:
   ```
   /help
   /status
   ```

## Congratulations! 🎉

Your MikroTik Telegram Bot is now running!

## What's Next?

### Essential Commands to Try

```
/status          - System overview
/interfaces      - Interface status
/dhcp            - DHCP leases
/backup now      - Create backup
```

### Activate Your Router

Before running RouterOS commands:

```
! YourRouterName
/ip address print
```

### Daily Usage

- **Check status**: `/status`
- **Monitor**: Automatic alerts when issues occur
- **Backup**: Runs automatically at 2 AM daily
- **Commands**: Activate router then send any RouterOS command

## Troubleshooting

### Bot doesn't respond?

**Check certificate**:
```routeros
/certificate print where common-name~"Go Daddy"
```

If not present, install it:
```routeros
/tool fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" mode=https dst-path=godaddy.pem
/certificate import file-name=godaddy.pem passphrase=""
```

**Check scheduler**:
```routeros
/system scheduler print where name="telegram-bot"
```

Should show `run-count` > 0 and `next-run` in the future.

**Check logs**:
```routeros
/log print where topics~"script"
```

Look for any error messages.

### Still having issues?

1. Review the full [Installation Guide](setup/installation.md)
2. Check [Troubleshooting](setup/installation.md#troubleshooting)
3. Ask in [Telegram Group](https://t.me/routeros_scripts)

## Advanced Setup

Once the basics work, explore:

- **[Custom Commands](README.md#custom-command-aliases)** - Add your own shortcuts
- **[Multi-Device](examples/usage-examples.md#multi-device-management)** - Manage multiple routers
- **[Monitoring Tuning](README.md#configuration)** - Adjust alert thresholds
- **[Security](setup/installation.md#security-recommendations)** - Harden your setup

## Quick Reference Card

```
Bot Control:
  ?              Check bot status
  ! router       Activate device
  ! @all         Activate all devices
  !              Deactivate

Information:
  /help          Command list
  /status        System status
  /interfaces    Interface stats
  /dhcp          DHCP leases
  /logs          System logs
  /traffic eth1  Traffic stats

Management:
  /backup now    Create backup
  /backup list   List backups
  /update check  Check updates
  /reboot confirm  Reboot router

Advanced:
  Activate device, then send any RouterOS command:
  ! router
  /ip address print
  /interface print stats
```

## Need More Help?

- **Full Documentation**: [README.md](README.md)
- **Detailed Setup**: [Installation Guide](setup/installation.md)
- **Examples**: [Usage Examples](examples/usage-examples.md)
- **Community**: [@routeros_scripts](https://t.me/routeros_scripts)

---

**Happy Routing!** 🚀

*Setup time: ~15 minutes | Complexity: Beginner-Friendly | Support: Community*

