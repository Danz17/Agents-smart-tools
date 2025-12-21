# Claude Relay Native Mode Setup (No Python Service Required)

Quick guide for using Claude Code Relay Node in **native RouterOS mode** - directly calling Claude API from the router without any Python service.

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

## Overview

Native mode allows the router to directly call Claude API using RouterOS scripts. **No Python service or external server required!**

### Advantages
- ✅ No external server needed
- ✅ No Python installation required
- ✅ Simpler setup
- ✅ Works anywhere the router has internet access
- ✅ No port forwarding or cloud setup needed

### Limitations
- ⚠️ API key stored on router (security consideration)
- ⚠️ No multi-threading (RouterOS is single-threaded)
- ⚠️ Slightly slower than Python service (but still fast)

## Quick Setup

### Step 1: Get Claude API Key

1. Visit [Anthropic Console](https://console.anthropic.com/)
2. Create an account or sign in
3. Generate an API key
4. Copy the key (starts with `sk-ant-...`)

### Step 2: Configure RouterOS

Connect to your router and run:

```routeros
# Enable native Claude relay
:global ClaudeRelayNativeEnabled true

# Set your Claude API key
:global ClaudeAPIKey "sk-ant-api03-..."

# Set model (optional, default is claude-3-5-sonnet-20241022)
:global ClaudeAPIModel "claude-3-5-sonnet-20241022"

# Set timeout (optional, default is 30s)
:global ClaudeAPITimeout 30s

# Enable auto-execute (optional)
:global ClaudeRelayAutoExecute true
```

### Step 3: Load Native Module

```routeros
/system script run modules/claude-relay-native
```

### Step 4: Reload Bot Configuration

```routeros
/system script run bot-config
```

### Step 5: Test

Send a natural language command in Telegram:
```
show interfaces
```

The bot should translate and execute it!

## Configuration Options

| Global Variable | Default | Description |
|----------------|---------|-------------|
| `ClaudeRelayNativeEnabled` | `false` | Enable native mode (direct API calls) |
| `ClaudeAPIKey` | `""` | Your Claude API key from Anthropic |
| `ClaudeAPIModel` | `claude-3-5-sonnet-20241022` | Claude model to use |
| `ClaudeAPITimeout` | `30s` | API request timeout |

## Native Mode vs Python Service Mode

### When to Use Native Mode
- ✅ You don't want to run a Python service
- ✅ You want the simplest setup
- ✅ Router has direct internet access
- ✅ You're okay with API key on router

### When to Use Python Service Mode
- ✅ You want multi-threaded processing
- ✅ You want to keep API key off the router
- ✅ You need advanced features (error suggestions, cloud server)
- ✅ You want to process multiple requests concurrently

## Security Considerations

**Important**: In native mode, your Claude API key is stored on the router.

**Best Practices:**
1. Use router user permissions to restrict script access
2. Don't share router access with untrusted users
3. Rotate API key regularly
4. Monitor API usage in Anthropic console
5. Consider using read-only API keys if available

## Troubleshooting

### API Key Not Working

```routeros
# Verify API key is set
:global ClaudeAPIKey
:put $ClaudeAPIKey

# Test API connection
/tool fetch url="https://api.anthropic.com/v1/messages" \
  http-method=post \
  http-header-field=("x-api-key: " . $ClaudeAPIKey) \
  http-header-field="anthropic-version: 2023-06-01" \
  http-header-field="Content-Type: application/json" \
  http-data="{\"model\":\"claude-3-5-sonnet-20241022\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"test\"}]}"
```

### Module Not Loading

```routeros
# Check if file exists
/file print where name~"claude-relay-native"

# Manually load
/system script run modules/claude-relay-native

# Check logs
/log print where topics~"claude-relay-native"
```

### Commands Not Processing

```routeros
# Verify native mode is enabled
:global ClaudeRelayNativeEnabled
:put $ClaudeRelayNativeEnabled

# Test smart command processing
:global ProcessSmartCommandNative
[$ProcessSmartCommandNative "show interfaces"]
```

## Example Usage

Once configured, try these in Telegram:

- `show me all interfaces with errors`
- `block device 192.168.1.100`
- `show dhcp leases`
- `what's using the most bandwidth?`
- `show firewall rules`

## Switching Between Modes

You can switch between native and Python service modes:

```routeros
# Use native mode
:global ClaudeRelayNativeEnabled true
:global ClaudeRelayEnabled false

# Use Python service mode
:global ClaudeRelayNativeEnabled false
:global ClaudeRelayEnabled true

# Reload modules
/system script run modules/claude-relay-native
/system script run modules/claude-relay
```

**Note**: Native mode takes precedence if both are enabled.

---

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

