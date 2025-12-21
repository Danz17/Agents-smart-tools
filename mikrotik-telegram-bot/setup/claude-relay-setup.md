# Claude Code Relay Node Setup Guide

This guide explains how to set up and configure the Claude Code Relay Node for smart command processing in TxMTC.

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

## Overview

The Claude Code Relay Node enables intelligent command processing by translating natural language and high-level commands into RouterOS commands using Claude AI. This allows users to interact with the router using plain English instead of memorizing RouterOS syntax.

## Architecture

```
Telegram Message → bot-core.rsc → claude-relay.rsc → Python Service → Claude API
                                                      ↓
                                              RouterOS Command → Execute on Router
```

## Prerequisites

1. **Python 3.8+** installed on a server/computer accessible from your router
2. **Claude API Key** from Anthropic (or local Claude instance)
3. **Network connectivity** between router and Python service
4. **RouterOS 7.15+** with TxMTC bot installed

## Installation

### Step 1: Install Python Dependencies

On your server/computer, install required Python packages:

```bash
pip install flask flask-cors requests
```

Or using a virtual environment (recommended):

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install flask flask-cors requests
```

### Step 2: Configure Claude API

#### Option A: Anthropic API (Cloud)

1. Get your API key from [Anthropic Console](https://console.anthropic.com/)
2. Set environment variable:

```bash
export CLAUDE_API_KEY="your-api-key-here"
```

#### Option B: Local Claude Instance

If you have a local Claude instance (e.g., via Ollama), configure:

```bash
export CLAUDE_MODE="local"
export CLAUDE_API_URL="http://localhost:11434/v1/messages"
export CLAUDE_MODEL="claude"
```

### Step 3: Configure Python Service

Copy `claude-relay-config.example.json` to `claude-relay-config.json` and edit:

```json
{
  "service": {
    "host": "0.0.0.0",
    "port": 5000
  },
  "claude": {
    "mode": "anthropic",
    "api_key": "YOUR_CLAUDE_API_KEY_HERE"
  }
}
```

Or use environment variables:

```bash
export CLAUDE_RELAY_PORT=5000
export CLAUDE_RELAY_HOST=0.0.0.0
export CLAUDE_API_KEY="your-api-key"
export CLAUDE_MODEL="claude-3-5-sonnet-20241022"
```

### Step 4: Start Python Service

```bash
python3 claude-relay-node.py
```

The service will start on port 5000 (or your configured port). Verify it's running:

```bash
curl http://localhost:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "claude-relay-node",
  "timestamp": "2025-01-20T10:00:00",
  "config": {
    "mode": "anthropic",
    "api_configured": true
  }
}
```

### Step 5: Configure RouterOS

Edit `bot-config.rsc` on your router:

```routeros
# Enable Claude relay
:global ClaudeRelayEnabled true

# Set service URL (replace with your server IP)
:global ClaudeRelayURL "http://192.168.1.100:5000"

# Set timeout
:global ClaudeRelayTimeout 10s

# Set mode
:global ClaudeRelayMode "anthropic"

# Auto-execute translated commands (optional)
# When enabled, smart commands are automatically executed after translation
:global ClaudeRelayAutoExecute true

# Enable error suggestions (optional)
# When enabled, Claude analyzes command errors and suggests fixes
:global ClaudeRelayErrorSuggestions true
```

Then reload configuration:

```routeros
/system script run bot-config
```

### Step 6: Load Claude Relay Module

The module should auto-load, but you can manually load it:

```routeros
/system script run modules/claude-relay
```

Verify it's loaded:

```routeros
:global ClaudeRelayLoaded
:put $ClaudeRelayLoaded
```

Should output: `true`

## Usage

### Natural Language Commands

Once configured, you can use natural language commands in Telegram:

**Examples:**

- `show me all interfaces with errors` → `/interface print where status!="up"`
- `block device 192.168.1.100` → `/ip firewall filter add chain=forward src-address=192.168.1.100 action=drop`
- `show dhcp leases` → `/ip dhcp-server lease print`
- `what's using the most bandwidth?` → `/interface monitor-traffic once`
- `show firewall rules` → `/ip firewall filter print`

### Auto-Execute Mode

When `ClaudeRelayAutoExecute` is enabled:
- Smart commands are automatically translated and executed
- You'll see a confirmation message showing the translation
- No need to manually send the RouterOS command

**Example:**
```
You: show interfaces
Bot: 🤖 Translated: "show interfaces" → "/interface print stats"
     Executing...
Bot: ⚡ TxMTC | Result
     ⚙️ Command: /interface print stats
     📝 Output: [interface list]
```

### Error Suggestions

When `ClaudeRelayErrorSuggestions` is enabled:
- If a command fails, Claude analyzes the error
- Suggestions are provided on how to fix the command
- Includes corrected commands and alternative approaches

**Example:**
```
You: /ip address add address=192.168.1.1/24 interface=ether99
Bot: ⚡ TxMTC | Result
     ⚙️ Command: /ip address add address=192.168.1.1/24 interface=ether99
     ❌ Command failed with an error!
     📝 Output: [error: interface not found]
     
     💡 Suggestion:
     The interface 'ether99' does not exist. 
     Use '/interface print' to list available interfaces.
     Corrected command: /ip address add address=192.168.1.1/24 interface=ether1
```

### Smart Command Detection

The bot automatically detects smart commands when:
- Command doesn't start with `/` (RouterOS syntax)
- Command starts with common verbs: `show`, `block`, `unblock`, `what`, `how`, `list`, `get`, `find`, `check`

### Fallback Behavior

If Claude relay is unavailable or processing fails:
- Bot will notify you of the error
- You can still use direct RouterOS commands
- Smart command processing is optional and doesn't break normal operation

## Configuration Options

### Python Service Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `CLAUDE_RELAY_PORT` | `5000` | HTTP server port |
| `CLAUDE_RELAY_HOST` | `0.0.0.0` | Bind address |
| `CLAUDE_API_KEY` | (required) | Anthropic API key |
| `CLAUDE_API_URL` | `https://api.anthropic.com/v1/messages` | Claude API endpoint |
| `CLAUDE_MODEL` | `claude-3-5-sonnet-20241022` | Claude model to use |
| `CLAUDE_MODE` | `anthropic` | `anthropic` or `local` |
| `MAX_WORKERS` | `10` | Thread pool size |
| `REQUEST_TIMEOUT` | `30` | Request timeout (seconds) |
| `KNOWLEDGE_BASE_PATH` | `claude-relay-knowledge.json` | Knowledge base file path |

### RouterOS Configuration

| Global Variable | Default | Description |
|----------------|---------|-------------|
| `ClaudeRelayEnabled` | `false` | Enable/disable smart command processing |
| `ClaudeRelayURL` | `http://192.168.1.100:5000` | Python service URL |
| `ClaudeRelayTimeout` | `10s` | Request timeout |
| `ClaudeRelayMode` | `anthropic` | `anthropic` or `local` |
| `ClaudeRelayAutoExecute` | `false` | Auto-execute translated commands (when enabled, commands are automatically executed after translation) |
| `ClaudeRelayErrorSuggestions` | `false` | Enable error suggestions (when enabled, Claude analyzes command errors and suggests fixes) |

## Security Considerations

1. **API Key Protection**: Never commit API keys to version control
2. **Network Security**: Use HTTPS if service is exposed to internet
3. **Firewall Rules**: Restrict access to Python service port
4. **Command Validation**: All generated commands are validated before execution
5. **Dangerous Commands**: Blocked commands are never generated

## Troubleshooting

### Service Not Available

**Check 1: Service is running**
```bash
curl http://localhost:5000/health
```

**Check 2: Router can reach service**
```routeros
/tool fetch url="http://192.168.1.100:5000/health"
```

**Check 3: Firewall rules**
Ensure router can access service port (default 5000)

### API Key Issues

**Check API key is set:**
```bash
echo $CLAUDE_API_KEY
```

**Test API connection:**
```bash
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: YOUR_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":1024,"messages":[{"role":"user","content":"test"}]}'
```

### Module Not Loading

**Check module exists:**
```routeros
/file print where name~"claude-relay"
```

**Manually load module:**
```routeros
/system script run modules/claude-relay
```

**Check logs:**
```routeros
/log print where topics~"claude-relay"
```

### Commands Not Processing

**Check Claude relay is enabled:**
```routeros
:global ClaudeRelayEnabled
:put $ClaudeRelayEnabled
```

**Check service availability:**
```routeros
:global ClaudeRelayAvailable
[$ClaudeRelayAvailable]
:put $ClaudeRelayAvailable
```

**Test smart command processing:**
```routeros
:global ProcessSmartCommand
[$ProcessSmartCommand "show interfaces"]
```

## Advanced Configuration

### Custom Knowledge Base

Edit `claude-relay-knowledge.json` to add custom command patterns and examples.

### Rate Limiting

Configure rate limiting in Python service to prevent abuse.

### Logging

Python service logs to console. For production, configure file logging:

```python
import logging
logging.basicConfig(
    filename='claude-relay.log',
    level=logging.INFO
)
```

## Performance

- **Response Time**: Typically 1-3 seconds per command
- **Concurrent Requests**: Supports multiple simultaneous requests (configurable)
- **Resource Usage**: Minimal CPU/memory on router (processing done externally)

## Support

For issues or questions:
1. Check logs: `/log print where topics~"claude-relay"`
2. Test service: `curl http://your-service:5000/health`
3. Review configuration in `bot-config.rsc`
4. See [FAQ.md](../FAQ.md) for common issues

---

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

