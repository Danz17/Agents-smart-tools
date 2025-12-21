# Claude Device Authorization Setup

Guide for authorizing your router to use Claude API through a secure browser-based flow.

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

## Overview

Instead of manually entering your Claude API key on the router, you can use a secure device authorization flow:

1. **Router generates** a unique authorization code
2. **User visits** a web page with the code
3. **User enters** their Claude API key in the browser
4. **API key is stored** on the router (device-specific)
5. **Token works only** for that specific router device

## Prerequisites

- Claude Relay Node Python service running (for device authorization endpoints)
- Router has internet access
- Claude API key from [Anthropic Console](https://console.anthropic.com/)

## Quick Setup

### Step 1: Configure RouterOS

```routeros
# Enable native Claude relay
:global ClaudeRelayNativeEnabled true

# Set Claude relay service URL (where Python service is running)
:global ClaudeRelayURL "http://your-server:5000"

# Load native module
/system script run modules/claude-relay-native

# Reload bot config
/system script run bot-config
```

### Step 2: Request Authorization

#### Option A: Via Telegram Bot

Send this command in Telegram:
```
/authorize-claude
```

The bot will:
1. Request an authorization code
2. Display the authorization URL
3. Poll for authorization status
4. Store the API key once authorized

#### Option B: Via RouterOS Terminal

```routeros
:global AuthorizeDevice
[$AuthorizeDevice]
```

This will:
1. Generate device code
2. Display authorization URL in logs
3. Poll for authorization (up to 5 minutes)
4. Store API key automatically

### Step 3: Authorize in Browser

1. **Copy the authorization URL** from Telegram or router logs
2. **Open the URL** in your browser
3. **Enter your Claude API key** (starts with `sk-ant-`)
4. **Click "Authorize Device"**

The API key is now stored on your router and tied to this device only.

## How It Works

### Authorization Flow

```
┌─────────┐         ┌──────────────┐         ┌──────────┐
│ Router  │────────▶│ Python       │────────▶│ Browser  │
│         │ Request │ Service      │  URL    │          │
│         │ Code    │              │────────▶│          │
│         │◀────────│              │         │          │
│         │ Code    │              │         │          │
│         │         │              │◀────────│          │
│         │         │              │ API Key │          │
│         │ Poll    │              │         │          │
│         │────────▶│              │         │          │
│         │◀────────│              │         │          │
│         │ API Key │              │         │          │
└─────────┘         └──────────────┘         └──────────┘
```

### Security Features

- ✅ **Device-specific**: Each router gets a unique device code
- ✅ **Time-limited**: Device codes expire after 24 hours
- ✅ **One-time use**: API key is retrieved once and stored on router
- ✅ **Secure storage**: API key stored in RouterOS global variable
- ✅ **No key exposure**: API key never appears in router logs after storage

## API Endpoints

The Python service provides these endpoints:

### `/auth/request` (POST)
Request device authorization code.

**Request:**
```json
{
  "router_id": "RouterOS-Identity",
  "router_identity": "My Router"
}
```

**Response:**
```json
{
  "success": true,
  "device_code": "abc123...",
  "authorization_url": "http://server:5000/auth/abc123...",
  "expires_in": 86400
}
```

### `/auth/<device_code>` (GET/POST)
Web page for user to enter API key.

- **GET**: Shows authorization form
- **POST**: Submits API key

### `/auth/poll` (POST)
Poll for authorization status.

**Request:**
```json
{
  "device_code": "abc123..."
}
```

**Response (Pending):**
```json
{
  "success": true,
  "authorized": false,
  "status": "pending"
}
```

**Response (Authorized):**
```json
{
  "success": true,
  "authorized": true,
  "api_key": "sk-ant-api03-...",
  "router_id": "RouterOS-Identity"
}
```

## RouterOS Functions

### `RequestDeviceAuthorization`
Request a new device authorization code.

```routeros
:global RequestDeviceAuthorization
:local Result [$RequestDeviceAuthorization]
:put ($Result->"authorization_url")
```

### `PollDeviceAuthorization`
Check if device has been authorized.

```routeros
:global PollDeviceAuthorization
:local Result [$PollDeviceAuthorization "device-code-here"]
:if (($Result->"authorized") = true) do={
  :put ($Result->"api_key")
}
```

### `AuthorizeDevice`
Complete authorization flow (request + poll until authorized).

```routeros
:global AuthorizeDevice
:local Result [$AuthorizeDevice]
:if (($Result->"success") = true) do={
  :put "Device authorized!"
}
```

## Troubleshooting

### "Authorization timeout"

The authorization code expired (24 hours) or user didn't authorize within 5 minutes.

**Solution:** Request a new authorization code.

### "Invalid or expired device code"

The device code doesn't exist or has expired.

**Solution:** Request a new authorization code.

### "Claude relay service URL not configured"

`ClaudeRelayURL` is not set.

**Solution:**
```routeros
:global ClaudeRelayURL "http://your-server:5000"
```

### "Authorization function not available"

Native module not loaded.

**Solution:**
```routeros
/system script run modules/claude-relay-native
```

### Authorization URL not accessible

Check:
1. Python service is running
2. Firewall allows connections to service port
3. Service URL is correct
4. Router can reach the service

## Manual Authorization (Fallback)

If device authorization doesn't work, you can still set the API key manually:

```routeros
:global ClaudeAPIKey "sk-ant-api03-..."
```

**Note:** Manual entry is less secure as the key appears in command history.

## Security Best Practices

1. ✅ Use device authorization instead of manual entry
2. ✅ Keep API keys secure - don't share them
3. ✅ Rotate API keys regularly
4. ✅ Monitor API usage in Anthropic Console
5. ✅ Use router user permissions to restrict script access
6. ✅ Don't share router access with untrusted users

## Example Usage

### Complete Setup Flow

```routeros
# 1. Enable native mode
:global ClaudeRelayNativeEnabled true

# 2. Set service URL
:global ClaudeRelayURL "http://192.168.1.100:5000"

# 3. Load module
/system script run modules/claude-relay-native

# 4. Request authorization
:global AuthorizeDevice
[$AuthorizeDevice]

# 5. Check if API key is set
:global ClaudeAPIKey
:if ([:len $ClaudeAPIKey] > 10) do={
  :put "API key is configured!"
} else={
  :put "API key not set"
}
```

### Via Telegram

1. Send: `/authorize-claude`
2. Bot responds with authorization URL
3. Visit URL in browser
4. Enter API key
5. Bot confirms authorization

## Advanced: Custom Authorization Service

You can host your own authorization service by:

1. Running `claude-relay-node.py` on a server
2. Configuring router to use that server's URL
3. Using the same authorization flow

The authorization service can be:
- On your local network
- On a cloud server
- Behind a reverse proxy
- With custom domain/SSL

---

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

