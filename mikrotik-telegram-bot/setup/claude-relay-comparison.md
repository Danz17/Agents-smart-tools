# Claude Relay: Native vs Python Service Mode

Comparison guide to help you choose the right mode for your setup.

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

## Quick Comparison

| Feature | Native Mode | Python Service Mode |
|---------|-------------|---------------------|
| **Setup Complexity** | ⭐ Simple | ⭐⭐ Moderate |
| **External Server** | ❌ Not needed | ✅ Required |
| **Python Installation** | ❌ Not needed | ✅ Required |
| **API Key Location** | RouterOS | Python Service |
| **Multi-threading** | ❌ No (RouterOS limitation) | ✅ Yes |
| **Cloud Server** | ❌ No | ✅ Yes (port 8899) |
| **Error Suggestions** | ❌ No | ✅ Yes |
| **Handshake Security** | ❌ No | ✅ Yes |
| **Response Time** | ~2-4 seconds | ~1-3 seconds |
| **Concurrent Requests** | Sequential | Parallel |

## Native Mode (Recommended for Most Users)

### When to Use
- ✅ You want the simplest setup
- ✅ You don't want to run a Python service
- ✅ Router has direct internet access
- ✅ You're okay with API key on router
- ✅ Single user or low traffic

### Setup
```routeros
:global ClaudeRelayNativeEnabled true
:global ClaudeAPIKey "sk-ant-api03-..."
/system script run modules/claude-relay-native
```

**See**: [claude-relay-native-setup.md](claude-relay-native-setup.md)

### Advantages
- No external dependencies
- Works immediately after configuration
- No port forwarding needed
- No server maintenance

### Limitations
- API key stored on router
- No multi-threading (requests processed sequentially)
- No error suggestions
- No cloud server support

## Python Service Mode (Advanced Features)

### When to Use
- ✅ You want multi-threaded processing
- ✅ Multiple users or high traffic
- ✅ You want to keep API key off router
- ✅ You need cloud server access
- ✅ You want error suggestions
- ✅ You need handshake security

### Setup
1. Install Python service on server
2. Configure API key in Python service
3. Configure router to use service URL

**See**: [claude-relay-setup.md](claude-relay-setup.md)

### Advantages
- Multi-threaded processing
- API key stays off router
- Cloud server support
- Error suggestions
- Handshake security
- Better for production

### Limitations
- Requires external server
- More complex setup
- Requires Python installation
- Network connectivity needed

## Architecture Comparison

### Native Mode
```
Telegram → RouterOS → Claude API → RouterOS Command
```

### Python Service Mode
```
Telegram → RouterOS → Python Service → Claude API → RouterOS Command
```

## Performance

### Native Mode
- **First request**: ~2-4 seconds
- **Subsequent requests**: ~2-4 seconds (sequential)
- **Concurrent requests**: Processed one at a time

### Python Service Mode
- **First request**: ~1-3 seconds
- **Subsequent requests**: ~1-3 seconds (can be parallel)
- **Concurrent requests**: Processed in parallel (up to 10 workers)

## Security Comparison

### Native Mode
- ⚠️ API key stored in RouterOS script
- ✅ Direct HTTPS connection to Claude API
- ✅ No intermediate service
- ⚠️ API key visible to router administrators

### Python Service Mode
- ✅ API key stored in Python service (off router)
- ✅ Router only knows service URL
- ✅ Handshake mechanism available
- ✅ Can use firewall rules to restrict access

## Migration Between Modes

### Switch from Native to Python Service

```routeros
# Disable native mode
:global ClaudeRelayNativeEnabled false

# Enable Python service mode
:global ClaudeRelayEnabled true
:global ClaudeRelayURL "http://your-server:5000"

# Reload modules
/system script run modules/claude-relay
```

### Switch from Python Service to Native

```routeros
# Disable Python service mode
:global ClaudeRelayEnabled false

# Enable native mode
:global ClaudeRelayNativeEnabled true
:global ClaudeAPIKey "sk-ant-api03-..."

# Reload modules
/system script run modules/claude-relay-native
```

## Recommendation

**For most users**: Start with **Native Mode**
- Simplest setup
- No external dependencies
- Works great for personal use

**For production/enterprise**: Use **Python Service Mode**
- Better security (API key off router)
- Multi-threaded processing
- Advanced features (error suggestions, cloud server)

## Both Modes Can Coexist

You can have both modes configured, but only one active:

```routeros
# Configure both
:global ClaudeRelayNativeEnabled true
:global ClaudeRelayEnabled true

# Native mode takes precedence if both are enabled
# To use Python service, disable native:
:global ClaudeRelayNativeEnabled false
```

---

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

