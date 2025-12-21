# Claude Relay Cloud Server Setup

Quick guide for setting up Claude Code Relay Node with MikroTik Cloud server access.

Crafted with love & frustration by P̷h̷e̷n̷i̷x̷

## Overview

The cloud server feature allows the Python service to be accessed via your router's MikroTik Cloud IP or DDNS on port 8899, enabling remote access without exposing your local network.

## Quick Setup

### 1. Enable Cloud Server in Python Service

```bash
export CLAUDE_RELAY_ENABLE_CLOUD=true
export CLAUDE_RELAY_CLOUD_PORT=8899
export CLAUDE_RELAY_HANDSHAKE_SECRET="your-secret-key"  # Optional but recommended
```

Or in `claude-relay-config.json`:

```json
{
  "service": {
    "cloud_enabled": true,
    "cloud_port": 8899
  },
  "security": {
    "handshake_secret": "your-secret-key"
  }
}
```

### 2. Enable MikroTik Cloud on Router

```routeros
# Enable cloud service
/ip cloud set ddns-enabled=yes

# Verify cloud status
/ip cloud print

# Get your cloud IP or DDNS
:put [/ip cloud get public-address]
:put [/ip cloud get ddns-name]
```

### 3. Configure RouterOS

```routeros
# Enable Claude relay with cloud access
:global ClaudeRelayEnabled true
:global ClaudeRelayUseCloud true
:global ClaudeRelayCloudPort 8899
:global ClaudeRelayHandshakeSecret "your-secret-key"  # Must match Python service

# Reload configuration
/system script run bot-config

# Load module
/system script run modules/claude-relay

# Initialize cloud connection
:global ClaudeRelayInitCloud
[$ClaudeRelayInitCloud]
```

### 4. Verify Connection

```routeros
# Check if cloud connection is established
:global ClaudeRelayURL
:put "Service URL: " . $ClaudeRelayURL

# Test handshake
:global ClaudeRelayHandshake
[$ClaudeRelayHandshake]
```

## How It Works

1. **Router gets cloud IP/DDNS** from `/ip cloud`
2. **Router performs handshake** with Python service on port 8899
3. **Service verifies router identity** (with optional signature)
4. **Connection established** - `ClaudeRelayURL` is auto-configured
5. **All requests** go through cloud connection

## Handshake Mechanism

The handshake verifies the router's identity:

- **Router sends**: `router_identity`, `router_id`, `timestamp`, `signature` (if secret configured)
- **Service validates**: Identity and optional HMAC-SHA256 signature
- **Service responds**: Success confirmation with service info

## Security

- Use `CLAUDE_RELAY_HANDSHAKE_SECRET` for signature verification
- Set same secret on router: `ClaudeRelayHandshakeSecret`
- Cloud port (8899) should be restricted in firewall if possible
- Consider using HTTPS for production deployments

## Troubleshooting

### Cloud connection fails

```routeros
# Check cloud status
/ip cloud print

# Check if cloud IP is available
:put [/ip cloud get public-address]

# Manually test connection
/tool fetch url="http://YOUR_CLOUD_IP:8899/health"
```

### Handshake fails

- Verify `ClaudeRelayHandshakeSecret` matches on both sides
- Check Python service logs for handshake errors
- Ensure router identity is set: `/system identity print`

### Port not accessible

```routeros
# Allow cloud relay port in firewall
/ip firewall filter add chain=input protocol=tcp dst-port=8899 \
  action=accept comment="Claude Relay Cloud"
```

---

Crafted with love & frustration by P̷h̷e̷n̷i̷x̷
