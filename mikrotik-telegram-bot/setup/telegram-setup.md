# Telegram Bot Setup Guide

This guide walks you through creating a Telegram bot using BotFather and configuring it for use with your MikroTik router.

## Table of Contents
1. [Creating Your Bot](#creating-your-bot)
2. [Getting Your Chat ID](#getting-your-chat-id)
3. [Bot Configuration](#bot-configuration)
4. [Group Setup (Optional)](#group-setup-optional)
5. [Security Settings](#security-settings)

## Creating Your Bot

### Step 1: Start a Chat with BotFather

1. Open Telegram on your device (mobile or desktop)
2. Search for `@BotFather` (official bot with blue verification checkmark)
3. Click **START** to begin the conversation

### Step 2: Create a New Bot

1. Send the command: `/newbot`

2. BotFather will ask for a **name** for your bot
   - This can be anything, e.g., "My Router Monitor"
   - Example: `MikroTik Home Router`

3. Next, choose a **username** for your bot
   - Must end in `bot`
   - Must be unique across all Telegram
   - Example: `my_home_router_bot` or `HomeRouter_bot`

4. If successful, BotFather will send you:
   - A confirmation message
   - **Your bot token** (looks like `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
   - A link to your bot

**⚠️ IMPORTANT**: Save your bot token securely! This is like a password - anyone with this token can control your bot.

### Step 3: Customize Your Bot (Optional but Recommended)

#### Set Bot Description
```
/setdescription
```
Select your bot, then enter:
```
Monitors and manages my MikroTik router. Sends alerts and executes commands securely.
```

#### Set Bot About Text
```
/setabouttext
```
Select your bot, then enter:
```
MikroTik RouterOS management bot. Contact @yourusername for access.
```

#### Set Commands List
```
/setcommands
```
Select your bot, then paste:
```
help - Show all available commands
status - Get system status and health
backup - Create and manage backups
interfaces - Show interface statistics
dhcp - List DHCP leases
logs - View recent system logs
traffic - Show traffic statistics
update - Check for RouterOS updates
reboot - Reboot the router (requires confirmation)
```

#### Set Bot Profile Picture
```
/setuserpic
```
Select your bot, then upload an image (you can use the MikroTik logo or create a custom one).

## Getting Your Chat ID

Your Chat ID is needed so the bot knows who to send messages to.

### Method 1: Using the Bot

1. Find your bot in Telegram (use the link BotFather provided or search by username)
2. Click **START** to activate the bot
3. Send any message to the bot (e.g., "Hello")

4. On your MikroTik router, temporarily set the token:
   ```routeros
   :global TelegramTokenId "YOUR_BOT_TOKEN_HERE"
   ```

5. Run the helper function:
   ```routeros
   :global GetTelegramChatId
   $GetTelegramChatId
   ```

6. Check the logs or terminal output for your Chat ID:
   ```routeros
   /log print where topics~"script"
   ```
   
   You should see: `The chat id is: 987654321`

### Method 2: Using Web Tools

1. Send a message to your bot in Telegram
2. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Replace `<YOUR_BOT_TOKEN>` with your actual token
3. Look for `"chat":{"id":987654321` in the JSON response
4. Your Chat ID is the number after `"id":`

### Finding Your User ID (for Trusted Users)

Your user ID is different from the chat ID and is used for access control.

1. Message `@userinfobot` in Telegram
2. It will reply with your user ID
3. Add this ID to your trusted users list

Alternatively, use `@RawDataBot` - send it any message and it will show your complete user information.

## Bot Configuration

Now that you have your bot token and chat ID, configure your RouterOS script:

```routeros
# In bot-config.rsc or global-config-overlay

# Your bot token from BotFather
:global TelegramTokenId "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"

# Your personal chat ID
:global TelegramChatId "987654321"

# List of trusted user IDs (can use ID or username)
:global TelegramChatIdsTrusted ({
  987654321;        # Your user ID
  "@yourusername";  # Your username (alternative)
  123456789         # Additional trusted user
})

# Device groups (for managing multiple routers)
:global TelegramChatGroups "home,office,all"
```

## Group Setup (Optional)

If you want notifications and commands in a Telegram group:

### Creating a Group

1. Create a new group in Telegram
2. Add your bot to the group
3. **Important**: Make the bot an admin
   - Tap the group name → Administrators → Add Administrator
   - Select your bot
   - You can deny all permissions except "Read Messages"

### Getting Group Chat ID

1. Send a message in the group
2. Use the same methods as above to get updates
3. The group chat ID will be **negative** (e.g., `-123456789`)
4. Use this negative number as your `TelegramChatId`

### Using Topics (Telegram Forum Groups)

If your group has Topics enabled:

1. Send a message in a specific topic
2. Check the updates - look for `message_thread_id`
3. Set this in your config:
   ```routeros
   :global TelegramThreadId "123"
   ```

## Security Settings

### Privacy Settings

Configure your bot's privacy via BotFather:

```
/setprivacy
```

- **Enabled**: Bot only sees messages starting with `/` or direct mentions
- **Disabled**: Bot sees all messages (needed for chat functionality)

**Recommendation**: Disable privacy mode if using interactive commands.

### Join Groups Settings

```
/setjoingroups
```

- **Enabled**: Bot can be added to groups
- **Disabled**: Bot works only in private chats

**Recommendation**: Enable only if you need group functionality.

## Testing Your Setup

1. **Test basic connectivity:**
   ```routeros
   :global SendTelegram
   $SendTelegram "Test Message" "If you receive this, the bot is working!"
   ```

2. **Test command execution:**
   - Send `/help` to your bot
   - You should receive a list of commands

3. **Test monitoring:**
   - Wait a few minutes
   - Check if you receive any monitoring alerts

4. **Test command execution:**
   ```
   ! RouterName
   /system resource print
   ```

## Troubleshooting

### Bot Token Invalid
- Double-check you copied the entire token
- Make sure there are no spaces or extra characters
- The token should look like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

### Can't Get Chat ID
- Make sure you sent a message to the bot first
- Click START in the bot chat
- Wait a few seconds, then run `$GetTelegramChatId` again

### Bot Doesn't Respond in Groups
- Ensure the bot is an admin in the group
- Check that privacy mode is disabled
- Verify the group chat ID is correct (should be negative)

### Certificate Errors
Download the required certificate:
```routeros
/tool/fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" \
  mode=https dst-path=GoDaddyRootCertificateAuthorityG2.crt

/certificate import file-name=GoDaddyRootCertificateAuthorityG2.crt passphrase=""
```

## Security Best Practices

1. **Never Share Your Token**: Treat it like a password
2. **Use Private Chats**: Avoid public groups when possible
3. **Whitelist Users**: Only add trusted user IDs
4. **Regular Token Rotation**: Revoke and create new tokens periodically via:
   ```
   /revoke
   ```
5. **Monitor Access**: Check logs regularly for unauthorized attempts
6. **Secure Your Router**: Use strong passwords and firewall rules

## Next Steps

Once your bot is set up:

1. ✅ Proceed to [Installation Guide](installation.md)
2. ✅ Configure monitoring thresholds
3. ✅ Set up backup schedules
4. ✅ Test all commands
5. ✅ Review security settings

## Additional Resources

- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [BotFather Commands Reference](https://core.telegram.org/bots#6-botfather)
- [Telegram Bot Features](https://core.telegram.org/bots/features)

## Quick Reference

### Common BotFather Commands
- `/newbot` - Create a new bot
- `/token` - Get bot token
- `/setname` - Change bot name
- `/setdescription` - Change bot description
- `/setabouttext` - Change bot about text
- `/setuserpic` - Change bot profile picture
- `/setcommands` - Set bot commands list
- `/deletebot` - Delete bot
- `/revoke` - Revoke bot token (generate new one)

### Testing URLs
- Get updates: `https://api.telegram.org/bot<TOKEN>/getUpdates`
- Get bot info: `https://api.telegram.org/bot<TOKEN>/getMe`
- Send message: `https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>&text=Test`

---

**Need Help?** Check the [main README](../README.md) or join the [RouterOS Scripts Telegram group](https://t.me/routeros_scripts)

