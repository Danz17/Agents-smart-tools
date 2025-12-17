# Usage Examples

Comprehensive guide with real-world examples of using the MikroTik Telegram Bot.

## Table of Contents
1. [Basic Commands](#basic-commands)
2. [Device Management](#device-management)
3. [Monitoring & Alerts](#monitoring--alerts)
4. [Backup Management](#backup-management)
5. [Network Operations](#network-operations)
6. [Troubleshooting Scenarios](#troubleshooting-scenarios)
7. [Advanced Usage](#advanced-usage)
8. [Multi-Device Management](#multi-device-management)

## Basic Commands

### Check Bot Status

Simply ask if the bot is online:

```
?
```

**Response:**
```
🤖 Telegram Bot

Hello John!

Online (and active!), awaiting your commands!
```

### Get Help

View all available commands:

```
/help
```

**Response:**
```
📚 Bot Help

📱 Bot Control:
`?` - Check bot status
`! identity` - Activate device
`! @all` - Activate all devices

📊 Information:
`/status` - System status
`/interfaces` - Interface stats
`/dhcp` - DHCP leases
`/logs` - System logs

💾 Management:
`/backup` - Create backup
`/update` - Check updates

⚡ Advanced:
Activate device and send any RouterOS command
```

### System Status

Get a quick overview of system health:

```
/status
```

**Response:**
```
🖥️ System Status

📊 Resources:
• CPU: 24%
• RAM: 45% (234MB / 512MB)
• Disk: 15% (156MB / 1024MB)

⏱️ Uptime: 5d 12h 34m
📦 Version: 7.15
🏷️ Board: RB4011iGS+

🔌 Interfaces: 8/10 up
🔗 Connections: 142
```

## Device Management

### Activate Specific Device

Before sending commands, activate your router:

```
! HomeRouter
```

**Response:** (No response, device is now active)

Now you can send any RouterOS command:

```
/system resource print
```

**Response:**
```
⚙️ Command Result

⚙️ Command:
/system resource print

📝 Output:
uptime: 5d12h34m15s
version: 7.15 (stable)
build-time: Nov/20/2024 10:15:32
free-memory: 268435456
total-memory: 536870912
cpu: "ARM"
cpu-count: 4
cpu-frequency: 1400MHz
cpu-load: 24%
free-hdd-space: 879390720
total-hdd-space: 1073741824
architecture-name: "arm64"
board-name: "RB4011iGS+"
platform: "MikroTik"
```

### Deactivate Device

Make the device passive again:

```
!
```

This prevents accidental command execution.

### Reboot Router

Request a reboot (requires confirmation):

```
/reboot
```

**Response:**
```
⚠️ Reboot Confirmation Required

To reboot the router, send:
`/reboot confirm`

Or use: `! HomeRouter` then `/system reboot`
```

Confirm the reboot:

```
/reboot confirm
```

**Response:**
```
🔄 Rebooting router now...

I'll be back online shortly!
```

## Monitoring & Alerts

### Manual Status Check

Check system status at any time:

```
/status
```

### Automatic Alerts

The bot automatically sends alerts when thresholds are exceeded:

#### CPU Alert Example

When CPU usage exceeds 75% (configurable):

```
⚠️ CPU Utilization Alert

CPU utilization on HomeRouter is high!

Average: 82%
Threshold: 75%
Current: 85%
```

#### Recovery Notification

When CPU returns to normal:

```
✅ CPU Utilization Recovered

CPU utilization on HomeRouter returned to normal.

Average: 65%
```

#### RAM Alert Example

```
⚠️ RAM Utilization Alert

RAM utilization on HomeRouter is high!

Used: 88%
Total: 512MB
Used: 450MB
Free: 62MB
```

#### Disk Usage Alert

```
⚠️ Disk Usage Alert

Disk usage on HomeRouter is high!

Used: 92%
Total: 1GB
Used: 941MB
Free: 82MB
```

#### Temperature Alert

```
🌡️ Temperature Alert

Temperature on HomeRouter is high!

Current: 68°C
Threshold: 60°C
```

#### Interface Down Alert

```
🔌 Interface Down Alert

Interface ether2 on HomeRouter is down!
```

#### System Restart Notification

After a reboot, you'll automatically receive:

```
🔄 System Restarted

Router HomeRouter has restarted.

Uptime: 2m 15s
Version: 7.15
Board: RB4011iGS+
```

## Backup Management

### Create Manual Backup

Trigger an immediate backup:

```
/backup now
```

**Response:**
```
💾 Backup started! You will receive a notification when complete.
```

After completion:

```
💾 Backup Created

Backup created on HomeRouter

File: HomeRouter-241217-1430.backup
Size: 2.4MB

Download via: `/export file=HomeRouter-241217-1430`
Or access via FTP/WinBox
```

### List Available Backups

View all backup files on the router:

```
/backup list
```

**Response:**
```
💾 Available Backups

• HomeRouter-241217-1430.backup
   Size: 2.4MB | Date: dec/17/2024 14:30:15

• HomeRouter-241216-0200.backup
   Size: 2.3MB | Date: dec/16/2024 02:00:00

• HomeRouter-241215-0200.backup
   Size: 2.3MB | Date: dec/15/2024 02:00:00
```

### Automatic Backups

Backups run automatically at 2 AM daily (configurable). You'll receive notifications:

```
💾 Backup Created

Backup created successfully on HomeRouter

File: HomeRouter-241217-0200.backup
```

## Network Operations

### View Interfaces

Get interface status and statistics:

```
/interfaces
```

**Response:**
```
🔌 Interface Status

✅ ether1
   RX: 15234MB | TX: 8945MB
✅ ether2
   RX: 234MB | TX: 125MB
✅ bridge
   RX: 45678MB | TX: 23456MB
❌ ether10
   RX: 0MB | TX: 0MB
✅ wlan1
   RX: 8765MB | TX: 4321MB
```

### View DHCP Leases

See active DHCP clients:

```
/dhcp
```

**Response:**
```
📡 DHCP Leases

• `192.168.1.100` - Johns-iPhone
   AA:BB:CC:DD:EE:01

• `192.168.1.101` - Office-PC
   AA:BB:CC:DD:EE:02

• `192.168.1.102` - Smart-TV
   AA:BB:CC:DD:EE:03

• `192.168.1.105`
   AA:BB:CC:DD:EE:04
```

### View Traffic Statistics

Check traffic for a specific interface:

```
/traffic ether1
```

**Response:**
```
📊 Traffic Statistics: ether1

📥 RX: 15.2GB
📤 TX: 8.9GB
📦 RX Packets: 12456789
📦 TX Packets: 9876543
```

### View System Logs

Get recent log entries:

```
/logs
```

**Response:**
```
📋 Recent Logs

`14:30:15` script,info
Backup process completed

`14:25:42` system,info
DHCP assigned 192.168.1.105 to AA:BB:CC:DD:EE:04

`14:20:33` firewall,info
forward: in:ether1 out:bridge, connection state:new

_Showing last 10 entries_
```

Filter logs by keyword:

```
/logs error
```

Shows only log entries containing "error".

## Troubleshooting Scenarios

### Scenario 1: Client Can't Get Internet

**Step 1: Check interfaces**
```
/interfaces
```

Verify WAN interface (ether1) is up.

**Step 2: Check DHCP**
```
/dhcp
```

Verify client has received an IP address.

**Step 3: Check firewall**

Activate device and check firewall rules:
```
! HomeRouter
/ip firewall nat print
```

**Step 4: Check routes**
```
/ip route print
```

### Scenario 2: High CPU Usage

**Step 1: Check status**
```
/status
```

Note the CPU percentage.

**Step 2: View active connections**
```
! HomeRouter
/ip firewall connection print count-only
```

**Step 3: Check for CPU-intensive processes**
```
/system resource cpu print
```

**Step 4: View top talkers**
```
/tool torch interface=bridge
```

### Scenario 3: Running Out of Disk Space

**Step 1: Check status**
```
/status
```

Note disk usage percentage.

**Step 2: List files**
```
! HomeRouter
/file print
```

**Step 3: Remove old backups**
```
/file remove [find name~"old-backup"]
```

**Step 4: Clean log files**
```
/log print
/log print file=save-log
/log print without-paging
```

### Scenario 4: VPN Not Working

**Step 1: Check VPN status**
```
! HomeRouter
/interface l2tp-client print
```

**Step 2: Check routes**
```
/ip route print where dst-address=10.0.0.0/8
```

**Step 3: Check firewall**
```
/ip firewall filter print where chain=forward
```

**Step 4: Test connectivity**
```
/ping 10.0.0.1 count=5
```

## Advanced Usage

### Execute Complex Commands

Activate device and run multi-line scripts:

```
! HomeRouter
:foreach i in=[/ip firewall filter find where chain=forward] do={
  :put ([/ip firewall filter get $i comment] . ": " . [/ip firewall filter get $i])
}
```

### Export Configuration

```
! HomeRouter
/export file=my-config
```

Then download via FTP or WinBox.

### Check for Updates

```
/update check
```

**Response:**
```
📦 RouterOS Update Status

Current: 7.15
Latest: 7.16.1
Channel: stable

⬆️ Update available!
Use `/update install` to update
```

### Create Address List

```
! HomeRouter
/ip firewall address-list add list=allowed-ips address=192.168.1.100 comment="Johns-PC"
```

### Monitor Specific Interface

```
! HomeRouter
/interface monitor-traffic ether1 once
```

### Set Bandwidth Limit

```
! HomeRouter
/queue simple add name="guest-limit" target=192.168.2.0/24 max-limit=10M/10M
```

## Multi-Device Management

### Managing Multiple Routers

If you have multiple routers with the bot installed:

#### Activate All Devices

```
! @all
/system resource print
```

All routers in the "all" group will respond with their system resources.

#### Activate Specific Group

Configure groups in `bot-config.rsc`:
```routeros
:global TelegramChatGroups "home,all"  # On home router
:global TelegramChatGroups "office,all"  # On office router
```

Then activate by group:
```
! @home
/interface print stats
```

Only home routers respond.

#### Query All Devices

Ask which devices are online:

```
?
```

Each device responds separately.

### Example: Update All Routers

```
! @all
/system package update check-for-updates
```

Wait for responses, then:

```
! @all
/system package update download
```

Finally, reboot one at a time:

```
! HomeRouter
/system reboot

! OfficeRouter
/system reboot
```

### Example: Backup All Routers

```
! @all
/system script run modules/backup
```

All routers create backups and notify you.

## Tips and Best Practices

### 1. Use Reply-to for Quick Commands

When you receive a notification from a router, you can reply to that message with a command. The bot automatically knows which device to send it to.

### 2. Regular Health Checks

Create a routine to check your network:

```
/status
/interfaces
/dhcp
/logs
```

### 3. Test Backups Regularly

Once a month, download a backup and verify it:

```
/backup now
```

Then restore it on a test device.

### 4. Monitor Updates

Check for updates weekly:

```
/update check
```

### 5. Document Custom Configurations

When you make changes, document them:

```
! HomeRouter
/export file=config-$(date +%Y%m%d)
```

### 6. Use Descriptive Comments

When adding firewall rules or other configurations:

```
! HomeRouter
/ip firewall filter add chain=forward action=accept comment="Allow HomeRouter access"
```

### 7. Set Up Alerts for Critical Services

Monitor critical services with custom scripts:

```routeros
:if ([:len [/ip route find where gateway=192.168.1.1 active=yes]] = 0) do={
  $SendTelegram2 "Gateway Down" "Primary gateway is unreachable!"
}
```

## Common Command Reference

### Quick Status Checks
- `/status` - Overall system status
- `/interfaces` - Interface statistics
- `/dhcp` - DHCP leases
- `/logs` - Recent logs
- `/traffic [interface]` - Interface traffic

### Management
- `/backup [now|list]` - Backup management
- `/update [check|install]` - Update management
- `/reboot [confirm]` - Router reboot

### Bot Control
- `?` - Check bot status
- `! identity` - Activate device
- `! @group` - Activate group
- `!` - Deactivate

### Help
- `/help` - Show command list

## Security Reminders

1. **Never share your bot token** - Anyone with the token can control your router
2. **Whitelist trusted users only** - Don't add unknown user IDs
3. **Use strong passwords** - Protect your router with strong credentials
4. **Monitor command logs** - Regularly review who executed what
5. **Test in safe environment** - Try new commands in a test setup first
6. **Keep backups** - Always maintain recent backups
7. **Update regularly** - Keep RouterOS and scripts updated

## Getting More Help

- **Documentation**: Check the [README](../README.md)
- **Installation**: See [Installation Guide](../setup/installation.md)
- **Telegram Setup**: See [Telegram Bot Setup](../setup/telegram-setup.md)
- **Community**: Join [@routeros_scripts](https://t.me/routeros_scripts)
- **Issues**: Report bugs on GitHub

---

**Happy Routing!** 🚀

