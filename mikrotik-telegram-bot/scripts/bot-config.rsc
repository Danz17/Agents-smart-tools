#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Configuration
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Copy this file and customize it for your environment

# ============================================================================
# TELEGRAM BOT CREDENTIALS
# ============================================================================
# Get these from @BotFather on Telegram

# Bot token from BotFather (REQUIRED)
# Example: "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
:global TelegramTokenId
:if ([:typeof $TelegramTokenId] != "str" || [:len $TelegramTokenId] < 10) do={
  :set TelegramTokenId "8509387914:AAHdfl4A6Dgu1N0y1UfUtBkTN0SKqM7sfPs"
}

# Your personal chat ID (REQUIRED)
# Get this by messaging your bot and running $GetTelegramChatId
# Example: "987654321" or "-987654321" for groups
:global TelegramChatId
:if ([:typeof $TelegramChatId] != "str" || [:len $TelegramChatId] < 5) do={
  :set TelegramChatId "579243496"
}

# List of trusted user IDs who can control the bot
# Can be numeric IDs or usernames (with @ prefix)
# Add more users by separating with semicolons: ("id1";"id2";"@username")
:global TelegramChatIdsTrusted
:if ([:typeof $TelegramChatIdsTrusted] = "nothing" || [:len $TelegramChatIdsTrusted] = 0) do={
  :set TelegramChatIdsTrusted "579243496"
}

# Thread ID for topic groups (optional)
# Leave empty for regular groups or private chats
:global TelegramThreadId ""

# ============================================================================
# DEVICE IDENTIFICATION
# ============================================================================

# Router identity (uses system identity by default)
:global Identity [/system identity get name]

# Additional identity text (optional, e.g., "Home", "Office Main")
:global IdentityExtra ""

# Device groups this router belongs to
# Used for multi-device management with "! @groupname"
# Examples: "all", "home,all", "office,branch1,all"
:global TelegramChatGroups "all"

# ============================================================================
# MONITORING SETTINGS
# ============================================================================

# Enable automatic system monitoring
:global EnableAutoMonitoring true

# Monitoring check interval
# How often to check system health
:global MonitoringInterval "5m"

# CPU utilization threshold (percentage)
# Alert when average CPU usage exceeds this value
:global MonitorCPUThreshold 75

# RAM utilization threshold (percentage)
# Alert when RAM usage exceeds this value
:global MonitorRAMThreshold 80

# Disk usage threshold (percentage)
# Alert when disk usage exceeds this value
:global MonitorDiskThreshold 90

# Temperature threshold (Celsius)
# Alert when temperature exceeds this value
:global MonitorTempThreshold 60

# Voltage thresholds (Volts)
# Alert when voltage goes outside these ranges
:global MonitorVoltageMin 11.0
:global MonitorVoltageMax 13.5

# Interface monitoring
# Monitor these interfaces for status and errors
:global MonitorInterfaces "ether1,ether2,bridge,wlan1"
:global MonitorInterfaceMode "whitelist"  # whitelist or blacklist

# Monitoring type toggles
:global MonitorCPUEnabled true
:global MonitorRAMEnabled true
:global MonitorDiskEnabled true
:global MonitorInterfacesEnabled true
:global MonitorInternetEnabled true
:global MonitorTempEnabled true
:global MonitorVoltageEnabled true

# Traffic threshold (bytes per second)
# Alert on unusual traffic patterns
:global MonitorTrafficThreshold 100000000

# ============================================================================
# BACKUP SETTINGS
# ============================================================================

# Enable automatic backups
:global EnableAutoBackup true

# Backup schedule (cron format: "minute hour day month dayofweek")
# Examples:
#   "0 2 * * *"     - Daily at 2 AM
#   "0 2 * * 0"     - Weekly on Sunday at 2 AM
#   "0 2 1 * *"     - Monthly on 1st at 2 AM
:global BackupSchedule "0 2 * * *"

# Number of backups to keep (rotation)
# Older backups are automatically deleted
:global BackupRetention 7

# Automatically send backup files to Telegram
# Files are sent after creation (limited by Telegram's 50MB)
:global BackupAutoSend true

# Backup encryption password (optional but recommended)
# Leave empty for no encryption
:global BackupPassword ""

# Include configuration export (in addition to binary backup)
:global BackupIncludeExport true

# Upload backups to cloud (MikroTik Cloud)
:global BackupToCloud false

# ============================================================================
# NOTIFICATION SETTINGS
# ============================================================================

# Silent notifications (no sound/vibration)
# Set to true for non-urgent notifications
:global NotificationSilent false

# Send daily status summary
:global SendDailySummary true

# Daily summary time (24h format)
:global DailySummaryTime "08:00"

# Notification symbols (emojis)
# Set to false to disable emojis in notifications
:global UseNotificationSymbols true

# ============================================================================
# MESSAGE MANAGEMENT SETTINGS
# ============================================================================

# Message retention period (how long to keep messages before cleanup)
:global MessageRetentionPeriod 24h

# Never delete critical messages (alerts, errors, confirmations)
:global KeepCriticalMessages true

# Enable automatic message cleanup
:global AutoCleanupEnabled true

# How often to run cleanup (interval)
:global CleanupInterval 1h

# Last cleanup time (initialized on first run)
:global LastCleanupTime

# ============================================================================
# SCRIPT REGISTRY SETTINGS
# ============================================================================

# URL for script registry updates
:global ScriptRegistryURL "https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts-registry"

# Automatically update registry from remote
:global AutoUpdateRegistry false

# How often to check for registry updates
:global RegistryUpdateInterval 1d

# ============================================================================
# INTERACTIVE FEATURES SETTINGS
# ============================================================================

# Enable interactive menus with inline keyboards
:global EnableInteractiveMenus true

# Enable automatic script discovery
:global EnableScriptDiscovery true

# ============================================================================
# NETWATCH MONITORING
# ============================================================================

# Enable netwatch host/service monitoring
:global EnableNetwatchMonitor true

# Number of failed checks before alerting
:global NetwatchDownThreshold 3

# Repeat down alerts every N checks
:global NetwatchAlertRepeat 60

# ============================================================================
# ROUTEROS UPDATE CHECKER
# ============================================================================

# Enable RouterOS update notifications
:global EnableUpdateChecker true

# Update channel: stable, testing, development
:global UpdateChannel "stable"

# Automatically install patch updates
:global AutoInstallPatches false

# ============================================================================
# DHCP TO DNS SYNC
# ============================================================================

# Enable automatic DNS records from DHCP leases
:global EnableDHCPtoDNS true

# Domain suffix for DNS records
:global DHCPDNSDomain "lan.local"

# Extra name component (optional)
:global DHCPDNSNameExtra ""

# ============================================================================
# LOG MONITORING
# ============================================================================

# Enable log forwarding to Telegram
:global EnableLogMonitor true

# Topics to monitor (comma-separated)
:global LogMonitorTopics "critical,error,warning"

# Message patterns to exclude
:global LogMonitorExclude ""

# Max notifications per minute
:global LogMonitorMaxPerMinute 10

# ============================================================================
# SMS ACTIONS (LTE)
# ============================================================================

# Enable SMS command handler
:global EnableSMSActions false

# Authorized phone numbers for SMS commands
:global SMSAuthorizedNumbers ({})

# SMS action mappings
:global SMSActions ({
  "status"="/system script run bot-core";
  "reboot"="/system reboot";
  "backup"="/system backup save name=sms-backup"
})

# ============================================================================
# CERTIFICATE MONITORING
# ============================================================================

# Enable certificate expiry monitoring
:global EnableCertMonitor true

# Alert N days before certificate expires
:global CertExpiryDays 30

# ============================================================================
# CLAUDE CODE RELAY NODE SETTINGS
# ============================================================================

# Enable Claude Code Relay for smart command processing
# When enabled, natural language commands are processed via Claude API
# and translated to RouterOS commands
:global ClaudeRelayEnabled false

# Claude relay service URL (Python service endpoint)
# Example: "http://192.168.1.100:5000" or "https://claude-relay.example.com"
:global ClaudeRelayURL "http://192.168.1.100:5000"

# Request timeout for Claude relay service
:global ClaudeRelayTimeout 10s

# Claude API mode: "anthropic" (Anthropic API) or "local" (local Claude instance)
:global ClaudeRelayMode "anthropic"

# Auto-execute smart commands (when enabled, translated commands are automatically executed)
# If false, user must manually send the translated RouterOS command
:global ClaudeRelayAutoExecute false

# Enable error suggestions (when enabled, Claude analyzes command errors and suggests fixes)
:global ClaudeRelayErrorSuggestions false

# ============================================================================
# COMMAND EXECUTION SETTINGS
# ============================================================================

# Maximum command execution time (seconds)
# Commands exceeding this time continue in background
:global TelegramChatRunTime "20s"

# Random delay before polling (0-15 seconds)
# Prevents multiple devices from polling simultaneously
:global TelegramRandomDelay 5

# Command rate limiting (commands per minute per user)
:global CommandRateLimit 10

# Require confirmation for dangerous commands
# Commands like reboot, reset, etc. require explicit confirmation
:global RequireConfirmation true

# List of commands requiring confirmation
:global ConfirmationRequired ({
  "/system reset-configuration";
  "/system reboot";
  "/system shutdown";
  "/system package update install";
  "/file remove";
})

# ============================================================================
# SECURITY SETTINGS
# ============================================================================

# Log all commands to system log
:global LogAllCommands true

# Notify on untrusted access attempts
:global NotifyUntrustedAttempts true

# Maximum failed attempts before temporary block
:global MaxFailedAttempts 5

# Block duration after max failed attempts (minutes)
:global BlockDuration 30

# Enable command whitelist (if true, only whitelisted commands allowed)
:global EnableCommandWhitelist false

# Whitelisted commands (when whitelist is enabled)
:global CommandWhitelist ({
  "/ip address print";
  "/interface print";
  "/system resource print";
  "/log print";
})

# ============================================================================
# RUNTIME STATE (initialized if missing)
# ============================================================================

:global CommandRateLimitTracker;
:if ([:typeof $CommandRateLimitTracker] != "array") do={ :set CommandRateLimitTracker ({}) }

:global PendingConfirmations;
:if ([:typeof $PendingConfirmations] != "array") do={ :set PendingConfirmations ({}) }

:global BlockedUsers;
:if ([:typeof $BlockedUsers] != "array") do={ :set BlockedUsers ({}) }

:global DailySummaryLastSent;
:if ([:typeof $DailySummaryLastSent] != "str") do={ :set DailySummaryLastSent "" }

# ============================================================================
# ADVANCED SETTINGS
# ============================================================================

# Bot polling offset tracking
# Used internally to track last processed update
# Don't modify unless you know what you're doing
:global TelegramChatOffset
:if ([:typeof $TelegramChatOffset] != "array") do={ :set TelegramChatOffset { 0; 0; 0 } }

# Currently active chat session
# Set to true when bot is activated with "! identity"
:global TelegramChatActive
:if ([:typeof $TelegramChatActive] != "bool") do={ :set TelegramChatActive false }

# Message ID tracking for reply functionality
:global TelegramMessageIDs ({})

# Telegram queue for failed messages
:global TelegramQueue ({})

# Health check state tracking
:global CheckHealthLast ({})
:global CheckHealthCPUUtilization 0
:global CheckHealthCPUUtilizationNotified false
:global CheckHealthRAMUtilizationNotified false
:global CheckHealthDiskUtilizationNotified false
:global CheckHealthInternetConnectivity true
:global CheckHealthInterfaceDown ({})

# RouterOS update notification tracking
:global SentRouterosUpdateNotification ""

# ============================================================================
# CUSTOM COMMAND ALIASES
# ============================================================================
# Define shortcuts for common commands

:global CustomCommands ({
  "status"="/system resource print";
  "uptime"="/system resource get uptime";
  "version"="/system resource get version";
  "interfaces"="/interface print stats";
  "ip"="/ip address print";
  "dhcp"="/ip dhcp-server lease print";
  "wireless"="/interface wireless registration-table print";
  "logs"="/log print";
  "errors"="/log print where topics~\"error\"";
})

# ============================================================================
# INITIALIZATION
# ============================================================================

# Configuration ready flag
:global BotConfigReady true

# Print configuration status
:log info "MikroTik Telegram Bot configuration loaded"

# Verify required settings
:if ([:len $TelegramTokenId] = 0 || $TelegramTokenId = "YOUR_BOT_TOKEN_HERE") do={
  :log error "TelegramTokenId not configured! Please set your bot token."
}

:if ([:len $TelegramChatId] = 0 || $TelegramChatId = "YOUR_CHAT_ID_HERE") do={
  :log error "TelegramChatId not configured! Please set your chat ID."
}

:if ($TelegramTokenId != "YOUR_BOT_TOKEN_HERE" && $TelegramChatId != "YOUR_CHAT_ID_HERE") do={
  :log info "MikroTik Telegram Bot is ready! Send /help to your bot to start."
}

# ============================================================================
# NOTES
# ============================================================================
# 
# After editing this file:
# 1. Upload it to your RouterOS device
# 2. Import it: /import bot-config.rsc
# 3. Or run it: /system script run bot-config
#
# For help and documentation:
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# Based on RouterOS Scripts by eworm-de:
# https://github.com/eworm-de/routeros-scripts
#
# ============================================================================

