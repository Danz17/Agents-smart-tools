# Security Hardening Guide

Comprehensive guide to securing your MikroTik Telegram Bot installation.

## Table of Contents
1. [Threat Model](#threat-model)
2. [Essential Security Measures](#essential-security-measures)
3. [Bot Configuration Security](#bot-configuration-security)
4. [Network Security](#network-security)
5. [Access Control](#access-control)
6. [Monitoring & Auditing](#monitoring--auditing)
7. [Incident Response](#incident-response)
8. [Security Checklist](#security-checklist)

## Threat Model

### Potential Threats

1. **Unauthorized Bot Access**: Attacker gains control of your bot
2. **Token Compromise**: Bot token is leaked or stolen
3. **Command Injection**: Malicious commands executed
4. **Information Disclosure**: Sensitive data leaked
5. **Denial of Service**: Bot or router overwhelmed
6. **Man-in-the-Middle**: Traffic intercepted (mitigated by HTTPS)

### Protection Goals

- ✅ Prevent unauthorized access
- ✅ Protect sensitive credentials
- ✅ Audit all actions
- ✅ Detect and respond to threats
- ✅ Maintain availability

## Essential Security Measures

### 1. Secure Your Bot Token

**Critical**: Your bot token is like a password. Anyone with it can control your bot.

**Best Practices:**

```routeros
# ✅ GOOD: Token in configuration file with restricted access
:global TelegramTokenId "1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"

# ❌ BAD: Token in scheduler or visible scripts
/system scheduler add on-event=":global token \"1234...\"" # Don't do this!
```

**Protect the token:**
1. Never commit to version control
2. Don't share in screenshots
3. Don't paste in public forums
4. Rotate regularly (every 90 days)
5. Use different tokens for test/production

**If compromised:**
```
1. Open Telegram → @BotFather
2. Send: /revoke
3. Select your bot
4. Create new bot or regenerate token
5. Update configuration
6. Review logs for unauthorized access
```

### 2. Implement User Whitelisting

**Only allow trusted users:**

```routeros
# Option 1: By numeric ID (most secure)
:global TelegramChatIdsTrusted ({
  123456789;     # Your primary account
  987654321      # Secondary trusted user
})

# Option 2: By username (less secure - usernames can change)
:global TelegramChatIdsTrusted ({
  123456789;
  "@trusteduser"
})

# ❌ AVOID: Too permissive
:global TelegramChatIdsTrusted ({})  # Empty = anyone can use!
```

**Get user IDs securely:**
```
1. Each user sends message to bot
2. Admin runs: $GetTelegramChatId
3. Admin adds ID to whitelist
4. Never add unknown IDs
```

### 3. Enable Command Logging

**Log all commands for audit trail:**

```routeros
:global LogAllCommands true
:global NotifyUntrustedAttempts true
```

**Review logs regularly:**
```routeros
# Check recent command executions
/log print where message~"executed:"

# Check untrusted access attempts
/log print where message~"untrusted contact"

# Export logs for external analysis
/log print file=security-audit-$(date)
```

### 4. Use Command Confirmation

**Require confirmation for dangerous commands:**

```routeros
:global RequireConfirmation true
:global ConfirmationRequired ({
  "/system reset-configuration";
  "/system reboot";
  "/system shutdown";
  "/user remove";
  "/ip service set";
  "/system package update install"
})
```

### 5. Implement Command Whitelist (Optional)

**For high-security environments:**

```routeros
# Enable whitelist mode
:global EnableCommandWhitelist true

# Only allow these commands
:global CommandWhitelist ({
  # Read-only commands
  "/system resource print";
  "/interface print";
  "/ip address print";
  "/log print";
  
  # Safe management
  "/system backup save";
  "/export file=";
  
  # Monitoring
  "/tool ping";
  "/tool traceroute"
})
```

**Whitelist pros/cons:**
- ✅ Maximum security
- ✅ Clear audit trail
- ❌ Less flexible
- ❌ Requires maintenance

## Bot Configuration Security

### Secure Configuration Storage

**Method 1: Configuration Overlay (Recommended)**

```routeros
# Create overlay file (not tracked in git)
/file edit bot-config-local.rsc

# Add your secrets
:global TelegramTokenId "YOUR_SECRET_TOKEN"
:global TelegramChatId "YOUR_CHAT_ID"
:global BackupPassword "YOUR_BACKUP_PASSWORD"

# Import overlay after main config
/import bot-config.rsc
/import bot-config-local.rsc
```

**Method 2: Environment-Specific Configs**

```routeros
# Production
/file edit bot-config-production.rsc

# Testing
/file edit bot-config-testing.rsc

# Development
/file edit bot-config-development.rsc

# Load appropriate config
/import bot-config-production.rsc
```

### Encrypt Sensitive Data

**Backup encryption:**

```routeros
# Enable backup encryption
:global BackupPassword "StrongPassword123!"

# Verify encrypted
/system backup save name=test password=$BackupPassword
/file print detail where name~"test.backup"
# Should show: encrypted: yes
```

**Certificate private keys:**
```routeros
# Protect certificate imports
/certificate import file-name=cert.p12 passphrase="CertPassword"
```

### Rate Limiting

**Prevent abuse:**

```routeros
# Limit commands per user per minute
:global CommandRateLimit 10

# Implement in bot-core.rsc
:global UserCommandCount ({})
:global UserCommandTimestamp ({})

# Check rate limit before executing
:if ($UserCommandCount->$UserId > $CommandRateLimit) do={
  # Block user temporarily
}
```

## Network Security

### Firewall Configuration

**Restrict management access:**

```routeros
# Create address list of allowed IPs
/ip firewall address-list add list=allowed-mgmt address=192.168.1.0/24 comment="LAN"
/ip firewall address-list add list=allowed-mgmt address=10.0.0.0/8 comment="VPN"

# Block external access to management
/ip firewall filter add chain=input protocol=tcp dst-port=8291 \
  src-address-list=!allowed-mgmt action=drop comment="Block external WinBox"

/ip firewall filter add chain=input protocol=tcp dst-port=22 \
  src-address-list=!allowed-mgmt action=drop comment="Block external SSH"

/ip firewall filter add chain=input protocol=tcp dst-port=80,443 \
  src-address-list=!allowed-mgmt action=drop comment="Block external WebFig"

# Allow Telegram API (outbound only - no need to allow inbound)
# Bot initiates connections, so no firewall rules needed
```

### Service Hardening

**Disable unnecessary services:**

```routeros
/ip service disable telnet,ftp,www

# Enable only required services
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no port=8291

# Restrict service access
/ip service set ssh address=192.168.0.0/16
/ip service set winbox address=192.168.0.0/16
```

**Use non-standard ports:**

```routeros
# Change SSH port
/ip service set ssh port=2222

# Change WinBox port
/ip service set winbox port=8192

# Update your firewall rules accordingly
```

### HTTPS/TLS

**Ensure secure communication:**

```routeros
# Verify certificate
/certificate print where common-name~"Go Daddy"

# Test HTTPS connection
/tool fetch url="https://api.telegram.org/botTOKEN/getMe" \
  mode=https check-certificate=yes-without-crl

# If fails, certificate is missing or invalid
```

## Access Control

### User Management

**Secure router users:**

```routeros
# Disable default admin (after creating new admin user)
/user add name=myadmin password=StrongPassword123 group=full
/user disable admin

# Create read-only user for monitoring
/user add name=monitor password=MonitorPass group=read

# Create limited user for bot (if needed)
/user group add name=bot-user policy=read,write,test
/user add name=botuser password=BotPass group=bot-user
```

### SSH Key Authentication

**Disable password authentication:**

```routeros
# Import your public key
/user ssh-keys import user=myadmin public-key-file=id_rsa.pub

# Disable password login (after testing key auth!)
# Be careful: test key login first!
# /ip ssh set always-allow-password-login=no
```

### Session Management

**Limit concurrent sessions:**

```routeros
# Check active sessions
/user active print

# Set session timeout
/ip service set ssh disabled=no keepalive-timeout=5m

# Limit login attempts
# (Not directly supported, use fail2ban or external tools)
```

## Monitoring & Auditing

### Comprehensive Logging

**Enable detailed logging:**

```routeros
# Log all topics to memory and disk
/system logging action add name=file-log target=disk

/system logging add topics=system,info action=memory
/system logging add topics=system,error,critical action=file-log
/system logging add topics=script,info action=memory
/system logging add topics=account,info action=file-log

# Log command executions
:global LogAllCommands true
```

### Security Monitoring

**Monitor for suspicious activity:**

```routeros
# Failed login attempts
/log print where message~"login failure"

# Untrusted bot access attempts
/log print where message~"untrusted contact"

# Configuration changes
/log print where topics~"system" and message~"changed"

# User additions
/log print where message~"user.*added"

# Service changes
/log print where topics~"system" and message~"service"
```

### Automated Alerts

**Alert on security events:**

```routeros
# Add to monitoring module or create security-monitoring script
:if ([:len [/log find where message~"login failure"]] > 5) do={
  $SendTelegram2 ({
    subject="🚨 Security Alert";
    message="Multiple failed login attempts detected!"
  })
}

# Alert on new users
:local UserCount [:len [/user find]]
:if ($UserCount > $ExpectedUserCount) do={
  $SendTelegram2 ({
    subject="⚠️ User Account Alert";
    message=("User count changed: " . $UserCount)
  })
}

# Alert on service changes
:if ([/ip service get ssh disabled] = false) do={
  :if ([/ip service get ssh port] != 22) do={
    $SendTelegram2 ({
      subject="⚠️ Service Configuration Changed";
      message="SSH port has been modified"
    })
  }
}
```

### Regular Security Audits

**Weekly audit script:**

```routeros
/system script add name=security-audit source={
  :global SendTelegram2
  
  :local Report "🔒 Weekly Security Audit\n\n"
  
  # Active users
  :set Report ($Report . "👥 Users: " . [:len [/user find]] . "\n")
  
  # Active sessions
  :set Report ($Report . "🔗 Sessions: " . [:len [/user active find]] . "\n")
  
  # Services enabled
  :set Report ($Report . "🔧 Services:\n")
  :foreach Service in=[/ip service find where disabled=no] do={
    :local SData [/ip service get $Service]
    :set Report ($Report . "  • " . ($SData->"name") . ":" . ($SData->"port") . "\n")
  }
  
  # Recent logins
  :local Logins [:len [/log find where message~"logged in" and time>1d]]
  :set Report ($Report . "🔑 Logins (24h): " . $Logins . "\n")
  
  # Failed attempts
  :local Failed [:len [/log find where message~"login failure" and time>1d]]
  :set Report ($Report . "❌ Failed (24h): " . $Failed . "\n")
  
  $SendTelegram2 ({ subject="Security Audit"; message=$Report; silent=true })
}

# Schedule weekly
/system scheduler add name=security-audit interval=7d start-time="06:00:00" \
  on-event="/system script run security-audit"
```

## Incident Response

### Detecting Compromise

**Signs of compromise:**
- Unexpected configuration changes
- Unknown users added
- Services enabled/ports changed
- Unknown firewall rules
- Unexpected schedules
- High CPU/bandwidth usage
- Unknown files in /file
- Modified scripts

### Immediate Response

**If compromise suspected:**

```routeros
# 1. Disable bot immediately
/system scheduler disable telegram-bot

# 2. Check active sessions
/user active print

# 3. Disconnect suspicious sessions
/user active remove [find]

# 4. Change passwords
/user set admin password=NewStrongPassword123

# 5. Review logs
/log print where time>1d
/log print file=incident-response-$(date)

# 6. Check configuration changes
/system history print

# 7. Revoke bot token
# Via @BotFather: /revoke

# 8. Review firewall
/ip firewall filter print
/ip firewall nat print

# 9. Check schedules
/system scheduler print

# 10. Verify scripts
/system script print detail
```

### Recovery Steps

1. **Isolate**: Disconnect from network if needed
2. **Assess**: Review logs and configuration
3. **Clean**: Remove unauthorized changes
4. **Restore**: From clean backup if needed
5. **Harden**: Implement additional security
6. **Monitor**: Watch for recurring issues
7. **Document**: Record incident details

### Post-Incident

```routeros
# Create backup after recovery
/system backup save name=post-incident-clean

# Update all passwords
/user set [find] password=NewSecurePassword

# Review and update security measures
# Re-import clean configurations
# Update firewall rules
# Enable additional monitoring
```

## Security Checklist

### Initial Setup

- [ ] Strong router password (16+ chars, mixed)
- [ ] Bot token kept secret
- [ ] User whitelist configured
- [ ] Command logging enabled
- [ ] Unnecessary services disabled
- [ ] Firewall rules configured
- [ ] SSH key authentication (optional)
- [ ] Backup encryption enabled

### Daily/Weekly

- [ ] Review command logs
- [ ] Check active sessions
- [ ] Monitor failed logins
- [ ] Verify no new users
- [ ] Check scheduler for unknown jobs
- [ ] Review /file for unknown files

### Monthly

- [ ] Update RouterOS
- [ ] Review firewall rules
- [ ] Audit user accounts
- [ ] Test backup restoration
- [ ] Review enabled services
- [ ] Check certificate validity
- [ ] Security audit report

### Quarterly

- [ ] Rotate bot token
- [ ] Change router passwords
- [ ] Review all configurations
- [ ] Update security policies
- [ ] Test incident response
- [ ] Review and update documentation

## Best Practices Summary

### ✅ Do

- Keep router OS updated
- Use strong, unique passwords
- Enable command logging
- Whitelist trusted users only
- Monitor logs regularly
- Test backups regularly
- Use encrypted backups
- Implement rate limiting
- Review access regularly
- Document changes
- Use private chats (not groups when possible)
- Keep token secret
- Test security measures

### ❌ Don't

- Share bot token publicly
- Use default passwords
- Disable logging
- Add unknown users
- Expose management to internet
- Use unencrypted backups
- Ignore log warnings
- Skip security updates
- Use same password everywhere
- Trust without verify
- Run untested commands
- Allow unnecessary services

## Additional Resources

- [MikroTik Security Guide](https://wiki.mikrotik.com/wiki/Manual:Securing_Your_Router)
- [Telegram Bot Security](https://core.telegram.org/bots/faq#security)
- [OWASP IoT Security](https://owasp.org/www-project-internet-of-things/)
- [CIS Router Hardening Guide](https://www.cisecurity.org/)

## Emergency Contacts

**If security incident occurs:**

1. **Isolate** the affected router
2. **Document** everything
3. **Notify** stakeholders
4. **Restore** from clean backup
5. **Investigate** root cause
6. **Improve** security measures

---

**Security is an ongoing process, not a one-time setup. Stay vigilant!** 🔒

