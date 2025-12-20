# TxMTC - Credentials Management

This document explains how to manage your Telegram bot credentials securely.

## Files

- **`.env`** - Your actual credentials (⚠️ **DO NOT COMMIT** - already in `.gitignore`)
- **`.env.example`** - Template file showing required variables (safe to commit)
- **`scripts/set-credentials.rsc`** - RouterOS script to set credentials directly
- **`scripts/load-credentials-from-file.rsc`** - RouterOS script to load from router file

## Quick Setup

### Option 1: Direct Setup (Recommended for First Time)

Edit `scripts/set-credentials.rsc` and update these lines:

```routeros
:local botToken "YOUR_BOT_TOKEN_HERE"
:local chatId "YOUR_CHAT_ID_HERE"
:local trustedIds "YOUR_CHAT_ID_HERE"
```

Then on your router:
```
/import set-credentials.rsc
/system script run bot-config
/system script run bot-core
```

### Option 2: Load from Router File

1. Create a credentials file on your router:
```
/file add name=txmtc-credentials.txt contents="TELEGRAM_TOKEN_ID=your_token\nTELEGRAM_CHAT_ID=your_chat_id\nTELEGRAM_CHAT_IDS_TRUSTED=your_trusted_ids"
```

2. Load credentials:
```
/system script run load-credentials-from-file
/system script run bot-config
/system script run bot-core
```

### Option 3: Manual Global Variables

On your router terminal:
```
:global TelegramTokenId "YOUR_BOT_TOKEN"
:global TelegramChatId "YOUR_CHAT_ID"
:global TelegramChatIdsTrusted "YOUR_CHAT_ID"
:global BotConfigReady true
```

**Note:** Global variables are lost on reboot. Use Option 1 or 2 for persistence.

## Getting Your Credentials

### Bot Token
1. Open Telegram and search for `@BotFather`
2. Send `/newbot` and follow instructions
3. Copy the token (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Chat ID
1. Send a message to your bot
2. Check router logs: `/log print where topics~"script"`
3. Or use `@userinfobot` on Telegram to get your user ID
4. For group chats, use `@getidsbot` or check bot logs

## Security Notes

- ⚠️ **Never commit `.env` file to Git** (already in `.gitignore`)
- ✅ The `.env` file is for local reference only
- ✅ RouterOS scripts handle credentials securely on the router
- ✅ Credentials are stored in a startup scheduler for persistence
- ✅ Use `set-credentials.rsc` or `load-credentials-from-file.rsc` for secure setup

## Current Credentials (from .env)

```
TELEGRAM_TOKEN_ID=8312205498:AAF4CtGBbrtqkZ753hm2WYduEKaBRLekxjM
TELEGRAM_CHAT_ID=579243496
TELEGRAM_CHAT_IDS_TRUSTED=579243496
```

## Troubleshooting

### Bot not responding?
1. Check credentials are set: `:put $TelegramTokenId`
2. Verify scheduler exists: `/system scheduler print where name~"telegram-bot-credentials"`
3. Check logs: `/log print where topics~"script"`

### Credentials lost after reboot?
- Use `set-credentials.rsc` or `load-credentials-from-file.rsc` to create persistent scheduler
- The scheduler runs on startup to restore credentials

### Multiple trusted users?
- Set `TELEGRAM_CHAT_IDS_TRUSTED` to comma-separated list: `"123456789,987654321"`
