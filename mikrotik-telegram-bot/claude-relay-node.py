#!/usr/bin/env python3
"""
Claude Code Relay Node - Smart Command Processor for RouterOS
Processes natural language and high-level commands using Claude API
and translates them to RouterOS commands.

Crafted with love & frustration by P̷h̷e̷n̷i̷x̷
"""

import os
import json
import logging
import threading
import secrets
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from typing import Dict, Optional, Any
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
CONFIG = {
    'port': int(os.getenv('CLAUDE_RELAY_PORT', 5000)),
    'cloud_port': int(os.getenv('CLAUDE_RELAY_CLOUD_PORT', 8899)),  # Port for cloud access
    'host': os.getenv('CLAUDE_RELAY_HOST', '0.0.0.0'),
    'claude_api_key': os.getenv('CLAUDE_API_KEY', ''),
    'claude_api_url': os.getenv('CLAUDE_API_URL', 'https://api.anthropic.com/v1/messages'),
    'claude_model': os.getenv('CLAUDE_MODEL', 'claude-3-5-sonnet-20241022'),
    'claude_mode': os.getenv('CLAUDE_MODE', 'anthropic'),  # 'anthropic' or 'local'
    'max_workers': int(os.getenv('MAX_WORKERS', 10)),
    'request_timeout': int(os.getenv('REQUEST_TIMEOUT', 30)),
    'knowledge_base_path': os.getenv('KNOWLEDGE_BASE_PATH', 'claude-relay-knowledge.json'),
    'enable_cloud': os.getenv('CLAUDE_RELAY_ENABLE_CLOUD', 'false').lower() == 'true',
    'handshake_secret': os.getenv('CLAUDE_RELAY_HANDSHAKE_SECRET', ''),  # Optional secret for handshake
}

# Thread pool for concurrent processing
executor = ThreadPoolExecutor(max_workers=CONFIG['max_workers'])

# Load RouterOS knowledge base
ROUTEROS_KNOWLEDGE = {}

# Device authorization storage (in-memory, can be persisted to file)
# Structure: {device_code: {api_key, router_id, router_identity, created_at, expires_at, authorized_at}}
DEVICE_AUTHORIZATIONS = {}
AUTHORIZATION_LOCK = threading.Lock()
AUTHORIZATION_EXPIRY_HOURS = 24  # Device codes expire after 24 hours


def load_knowledge_base() -> Dict[str, Any]:
    """Load RouterOS knowledge base from JSON file."""
    global ROUTEROS_KNOWLEDGE
    try:
        if os.path.exists(CONFIG['knowledge_base_path']):
            with open(CONFIG['knowledge_base_path'], 'r', encoding='utf-8') as f:
                ROUTEROS_KNOWLEDGE = json.load(f)
            logger.info(f"Loaded knowledge base from {CONFIG['knowledge_base_path']}")
        else:
            logger.warning(f"Knowledge base file not found: {CONFIG['knowledge_base_path']}")
            ROUTEROS_KNOWLEDGE = get_default_knowledge()
    except Exception as e:
        logger.error(f"Error loading knowledge base: {e}")
        ROUTEROS_KNOWLEDGE = get_default_knowledge()
    return ROUTEROS_KNOWLEDGE


def get_default_knowledge() -> Dict[str, Any]:
    """Return default RouterOS knowledge base."""
    return {
        "syntax_patterns": [
            "/interface print [where <condition>]",
            "/ip address print [where <condition>]",
            "/ip firewall filter add chain=<chain> action=<action> [src-address=<ip>] [dst-address=<ip>]",
            "/ip dhcp-server lease print [where <condition>]",
            "/system resource print",
            "/log print [where topics~\"<topic>\"]",
        ],
        "common_operations": {
            "show_interfaces": "/interface print stats",
            "show_errors": "/interface print where status!=\"up\"",
            "show_dhcp": "/ip dhcp-server lease print",
            "show_firewall": "/ip firewall filter print",
            "show_addresses": "/ip address print",
            "block_device": "/ip firewall filter add chain=forward src-address={ip} action=drop comment=\"Blocked via smart command\"",
            "unblock_device": "/ip firewall filter remove [find where src-address={ip} and action=drop]",
            "show_status": "/system resource print",
            "show_logs": "/log print",
        },
        "safety_rules": {
            "dangerous_commands": [
                "/system reset-configuration",
                "/system reset-configuration no-defaults=yes",
                "/system package uninstall",
            ],
            "read_only_safe": [
                "/interface print",
                "/ip address print",
                "/ip dhcp-server lease print",
                "/system resource print",
                "/log print",
            ],
        },
        "context_examples": [
            {
                "input": "show me all interfaces with errors",
                "output": "/interface print where status!=\"up\"",
            },
            {
                "input": "block device 192.168.1.100",
                "output": "/ip firewall filter add chain=forward src-address=192.168.1.100 action=drop comment=\"Blocked via smart command\"",
            },
            {
                "input": "what's using the most bandwidth?",
                "output": "/interface monitor-traffic once",
            },
        ],
    }


def build_system_prompt() -> str:
    """Build system prompt for Claude with RouterOS knowledge."""
    knowledge = ROUTEROS_KNOWLEDGE or get_default_knowledge()
    
    prompt = """You are a RouterOS command expert assistant. Your task is to translate natural language commands or high-level abstractions into valid RouterOS commands.

RouterOS Command Syntax:
- Commands start with "/" (e.g., /interface print)
- Use "where" clause for filtering (e.g., /interface print where status!="up")
- Use "find" for searching (e.g., /ip firewall filter find where src-address="192.168.1.0/24")
- Use "add" to create (e.g., /ip firewall filter add chain=forward action=drop)
- Use "remove" or "set" to modify (e.g., /ip firewall filter remove [find where ...])

Common Operations:
"""
    
    for op, cmd in knowledge.get("common_operations", {}).items():
        prompt += f"- {op}: {cmd}\n"
    
    prompt += """
Safety Rules:
- NEVER generate dangerous commands like /system reset-configuration
- Always validate command syntax before returning
- Prefer read-only commands when the intent is unclear
- Add comments to firewall rules for traceability

Examples:
"""
    
    for example in knowledge.get("context_examples", []):
        prompt += f"Input: {example['input']}\nOutput: {example['output']}\n\n"
    
    prompt += """
Instructions:
1. Analyze the user's request
2. Determine the appropriate RouterOS command
3. Return ONLY the RouterOS command, nothing else
4. If the request is ambiguous, return a safe read-only command
5. If the request cannot be fulfilled, return an error message starting with "ERROR:"

Return format: Just the RouterOS command, or "ERROR: <reason>" if not possible.
"""
    
    return prompt


def call_claude_api(user_message: str, custom_system_prompt: Optional[str] = None) -> Optional[str]:
    """Call Claude API to process smart command.
    
    Args:
        user_message: The user's message/command
        custom_system_prompt: Optional custom system prompt (if None, uses default)
    """
    if not CONFIG['claude_api_key']:
        logger.error("Claude API key not configured")
        return None
    
    system_prompt = custom_system_prompt or build_system_prompt()
    
    headers = {
        "x-api-key": CONFIG['claude_api_key'],
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
    }
    
    payload = {
        "model": CONFIG['claude_model'],
        "max_tokens": 1024,
        "system": system_prompt,
        "messages": [
            {
                "role": "user",
                "content": user_message
            }
        ]
    }
    
    try:
        response = requests.post(
            CONFIG['claude_api_url'],
            headers=headers,
            json=payload,
            timeout=CONFIG['request_timeout']
        )
        response.raise_for_status()
        result = response.json()
        
        # Extract content from Claude response
        if 'content' in result and len(result['content']) > 0:
            content = result['content'][0].get('text', '')
            return content.strip()
        else:
            logger.error(f"Unexpected Claude API response: {result}")
            return None
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Claude API request failed: {e}")
        return None
    except Exception as e:
        logger.error(f"Error processing Claude API response: {e}")
        return None


def validate_routeros_command(command: str):
    """Validate RouterOS command syntax and safety.
    
    Returns:
        tuple: (is_valid: bool, validated_command_or_error: str)
    """
    if not command or not command.strip():
        return False, "Empty command"
    
    command = command.strip()
    
    # Check for dangerous commands
    knowledge = ROUTEROS_KNOWLEDGE or get_default_knowledge()
    dangerous = knowledge.get("safety_rules", {}).get("dangerous_commands", [])
    
    for dangerous_cmd in dangerous:
        if command.startswith(dangerous_cmd):
            return False, f"Dangerous command blocked: {dangerous_cmd}"
    
    # Basic syntax validation
    if not command.startswith("/"):
        return False, "RouterOS commands must start with '/'"
    
    # Check for common syntax errors
    if "  " in command:  # Double spaces
        command = command.replace("  ", " ")
    
    return True, command


def process_smart_command(command: str, context: Optional[Dict] = None) -> Dict[str, Any]:
    """Process a smart command and return RouterOS command."""
    try:
        # Call Claude API
        routeros_command = call_claude_api(command)
        
        if not routeros_command:
            return {
                "success": False,
                "error": "Failed to process command with Claude API",
                "original_command": command,
            }
        
        # Check if Claude returned an error
        if routeros_command.startswith("ERROR:"):
            return {
                "success": False,
                "error": routeros_command.replace("ERROR:", "").strip(),
                "original_command": command,
            }
        
        # Validate the generated command
        is_valid, validated_command = validate_routeros_command(routeros_command)
        
        if not is_valid:
            return {
                "success": False,
                "error": validated_command or "Invalid command syntax",
                "original_command": command,
                "generated_command": routeros_command,
            }
        
        return {
            "success": True,
            "routeros_command": validated_command,
            "original_command": command,
        }
        
    except Exception as e:
        logger.error(f"Error processing smart command: {e}")
        return {
            "success": False,
            "error": str(e),
            "original_command": command,
        }


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "claude-relay-node",
        "timestamp": datetime.utcnow().isoformat(),
        "config": {
            "mode": CONFIG['claude_mode'],
            "api_configured": bool(CONFIG['claude_api_key']),
        }
    })


@app.route('/process-command', methods=['POST'])
def process_command():
    """Process a smart command and return RouterOS command."""
    try:
        data = request.get_json()
        
        if not data or 'command' not in data:
            return jsonify({
                "success": False,
                "error": "Missing 'command' in request body"
            }), 400
        
        command = data['command']
        context = data.get('context', {})
        
        # Process command asynchronously
        future = executor.submit(process_smart_command, command, context)
        result = future.result(timeout=CONFIG['request_timeout'])
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in process_command endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/execute', methods=['POST'])
def execute_command():
    """Execute RouterOS command remotely (optional feature)."""
    # This endpoint is for future use - direct execution from Python service
    # For now, we'll just validate and return the command
    try:
        data = request.get_json()
        
        if not data or 'command' not in data:
            return jsonify({
                "success": False,
                "error": "Missing 'command' in request body"
            }), 400
        
        command = data['command']
        is_valid, validated_command = validate_routeros_command(command)
        
        if not is_valid:
            return jsonify({
                "success": False,
                "error": validated_command or "Invalid command"
            }), 400
        
        # For now, just return the validated command
        # In the future, this could execute via SSH/API
        return jsonify({
            "success": True,
            "command": validated_command,
            "message": "Command validated (execution not implemented)"
        })
        
    except Exception as e:
        logger.error(f"Error in execute_command endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/handshake', methods=['POST'])
def handshake():
    """Handshake endpoint for router cloud connection verification."""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "Missing request body"
            }), 400
        
        router_identity = data.get('router_identity', '')
        router_id = data.get('router_id', '')
        timestamp = data.get('timestamp', '')
        signature = data.get('signature', '')
        
        # Basic handshake validation
        if not router_identity:
            return jsonify({
                "success": False,
                "error": "Missing router_identity"
            }), 400
        
        # Optional: Verify signature if handshake_secret is configured
        if CONFIG['handshake_secret']:
            import hmac
            import hashlib
            expected_signature = hmac.new(
                CONFIG['handshake_secret'].encode(),
                f"{router_identity}:{router_id}:{timestamp}".encode(),
                hashlib.sha256
            ).hexdigest()
            
            if signature != expected_signature:
                return jsonify({
                    "success": False,
                    "error": "Invalid handshake signature"
                }), 401
        
        # Successful handshake
        logger.info(f"Handshake successful from router: {router_identity} (ID: {router_id})")
        
        return jsonify({
            "success": True,
            "message": "Handshake successful",
            "service": "claude-relay-node",
            "version": "2.4.0",
            "timestamp": datetime.utcnow().isoformat(),
            "router_identity": router_identity,
            "cloud_port": CONFIG['cloud_port'],
        })
        
    except Exception as e:
        logger.error(f"Error in handshake endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


# ============================================================================
# DEVICE AUTHORIZATION HELPERS
# ============================================================================

def generate_device_code() -> str:
    """Generate a unique device authorization code."""
    return secrets.token_urlsafe(32)


def cleanup_expired_authorizations():
    """Remove expired device authorizations."""
    with AUTHORIZATION_LOCK:
        current_time = datetime.utcnow()
        expired_codes = [
            code for code, auth in DEVICE_AUTHORIZATIONS.items()
            if auth.get('expires_at') and auth['expires_at'] < current_time
        ]
        for code in expired_codes:
            del DEVICE_AUTHORIZATIONS[code]
        if expired_codes:
            logger.info(f"Cleaned up {len(expired_codes)} expired device authorizations")


def get_authorization_url(device_code: str, base_url: str = None) -> str:
    """Generate authorization URL for device code."""
    if base_url is None:
        # Try to determine base URL from request
        base_url = request.host_url.rstrip('/')
        if CONFIG['enable_cloud']:
            # Use cloud port if available
            base_url = base_url.replace(f":{CONFIG['port']}", f":{CONFIG['cloud_port']}")
    
    return f"{base_url}/auth/{device_code}"


# ============================================================================
# DEVICE AUTHORIZATION ENDPOINTS
# ============================================================================

@app.route('/auth/request', methods=['POST'])
def request_device_authorization():
    """Request device authorization - generates device code and returns authorization URL."""
    try:
        data = request.get_json() or {}
        
        router_id = data.get('router_id', '')
        router_identity = data.get('router_identity', '')
        
        if not router_id:
            router_id = data.get('device_id', '')
        
        if not router_id:
            return jsonify({
                "success": False,
                "error": "Missing 'router_id' or 'device_id' in request"
            }), 400
        
        # Generate device code
        device_code = generate_device_code()
        
        # Store authorization request
        with AUTHORIZATION_LOCK:
            DEVICE_AUTHORIZATIONS[device_code] = {
                'api_key': None,
                'router_id': router_id,
                'router_identity': router_identity or router_id,
                'created_at': datetime.utcnow(),
                'expires_at': datetime.utcnow() + timedelta(hours=AUTHORIZATION_EXPIRY_HOURS),
                'authorized_at': None,
                'status': 'pending'
            }
        
        # Generate authorization URL
        auth_url = get_authorization_url(device_code)
        
        logger.info(f"Device authorization requested: router_id={router_id}, device_code={device_code[:8]}...")
        
        return jsonify({
            "success": True,
            "device_code": device_code,
            "authorization_url": auth_url,
            "expires_in": AUTHORIZATION_EXPIRY_HOURS * 3600,  # seconds
            "message": f"Visit this URL to authorize: {auth_url}"
        })
        
    except Exception as e:
        logger.error(f"Error in request_device_authorization: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/auth/<device_code>', methods=['GET', 'POST'])
def device_authorization_page(device_code: str):
    """Web page for user to enter API key for device authorization."""
    try:
        # Cleanup expired codes
        cleanup_expired_authorizations()
        
        # Get authorization info
        with AUTHORIZATION_LOCK:
            auth_info = DEVICE_AUTHORIZATIONS.get(device_code)
        
        if not auth_info:
            return render_template_string("""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Device Authorization - Invalid Code</title>
                <style>
                    body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
                    .error { background: #fee; border: 1px solid #fcc; padding: 15px; border-radius: 5px; color: #c00; }
                </style>
            </head>
            <body>
                <h1>❌ Invalid Authorization Code</h1>
                <div class="error">
                    <p>This authorization code is invalid or has expired.</p>
                    <p>Please request a new authorization code from your router.</p>
                </div>
            </body>
            </html>
            """), 404
        
        # Check if already authorized
        if auth_info.get('api_key'):
            return render_template_string("""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Device Authorization - Already Authorized</title>
                <style>
                    body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
                    .success { background: #efe; border: 1px solid #cfc; padding: 15px; border-radius: 5px; color: #0a0; }
                </style>
            </head>
            <body>
                <h1>✅ Device Already Authorized</h1>
                <div class="success">
                    <p><strong>Router:</strong> {{ router_identity }}</p>
                    <p>This device has already been authorized.</p>
                    <p>You can close this page.</p>
                </div>
            </body>
            </html>
            """, router_identity=auth_info.get('router_identity', 'Unknown'))
        
        # Handle POST (API key submission)
        if request.method == 'POST':
            api_key = request.form.get('api_key', '').strip()
            
            if not api_key or len(api_key) < 10:
                return render_template_string("""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Device Authorization - Error</title>
                    <style>
                        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
                        .error { background: #fee; border: 1px solid #fcc; padding: 15px; border-radius: 5px; color: #c00; }
                        form { margin-top: 20px; }
                    </style>
                </head>
                <body>
                    <h1>Device Authorization</h1>
                    <div class="error">
                        <p>Invalid API key. Please enter a valid Claude API key.</p>
                    </div>
                    <form method="POST">
                        <label>Claude API Key:</label><br>
                        <input type="text" name="api_key" style="width: 100%; padding: 8px; margin: 10px 0;" placeholder="sk-ant-api03-..."><br>
                        <button type="submit" style="padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer;">Authorize Device</button>
                    </form>
                </body>
                </html>
                """)
            
            # Validate API key format (basic check)
            if not api_key.startswith('sk-ant-'):
                return render_template_string("""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Device Authorization - Error</title>
                    <style>
                        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
                        .error { background: #fee; border: 1px solid #fcc; padding: 15px; border-radius: 5px; color: #c00; }
                        form { margin-top: 20px; }
                    </style>
                </head>
                <body>
                    <h1>Device Authorization</h1>
                    <div class="error">
                        <p>Invalid API key format. Claude API keys should start with 'sk-ant-'.</p>
                    </div>
                    <form method="POST">
                        <label>Claude API Key:</label><br>
                        <input type="text" name="api_key" style="width: 100%; padding: 8px; margin: 10px 0;" placeholder="sk-ant-api03-..."><br>
                        <button type="submit" style="padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer;">Authorize Device</button>
                    </form>
                </body>
                </html>
                """)
            
            # Store API key
            with AUTHORIZATION_LOCK:
                if device_code in DEVICE_AUTHORIZATIONS:
                    DEVICE_AUTHORIZATIONS[device_code]['api_key'] = api_key
                    DEVICE_AUTHORIZATIONS[device_code]['authorized_at'] = datetime.utcnow()
                    DEVICE_AUTHORIZATIONS[device_code]['status'] = 'authorized'
            
            logger.info(f"Device authorized: router_id={auth_info.get('router_id')}, device_code={device_code[:8]}...")
            
            return render_template_string("""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Device Authorization - Success</title>
                <style>
                    body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
                    .success { background: #efe; border: 1px solid #cfc; padding: 15px; border-radius: 5px; color: #0a0; }
                    .info { background: #eef; border: 1px solid #ccf; padding: 15px; border-radius: 5px; margin-top: 15px; }
                </style>
            </head>
            <body>
                <h1>✅ Device Authorized Successfully!</h1>
                <div class="success">
                    <p><strong>Router:</strong> {{ router_identity }}</p>
                    <p>Your router has been authorized and can now use Claude API.</p>
                    <p>You can close this page.</p>
                </div>
                <div class="info">
                    <p><strong>Note:</strong> The API key is now stored on your router and tied to this device only.</p>
                </div>
            </body>
            </html>
            """, router_identity=auth_info.get('router_identity', 'Unknown'))
        
        # GET - Show authorization form
        return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Device Authorization</title>
            <style>
                body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
                .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                h1 { color: #333; }
                .info { background: #e3f2fd; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; }
                .warning { background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 20px 0; }
                label { display: block; margin: 15px 0 5px 0; font-weight: bold; color: #555; }
                input[type="text"] { width: 100%; padding: 12px; border: 2px solid #ddd; border-radius: 5px; font-size: 14px; box-sizing: border-box; }
                input[type="text"]:focus { border-color: #007bff; outline: none; }
                button { padding: 12px 30px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; margin-top: 10px; }
                button:hover { background: #0056b3; }
                .help { margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 5px; font-size: 14px; color: #666; }
                .help a { color: #007bff; text-decoration: none; }
                .help a:hover { text-decoration: underline; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🔐 Authorize Router Device</h1>
                
                <div class="info">
                    <p><strong>Router:</strong> {{ router_identity }}</p>
                    <p><strong>Device ID:</strong> {{ router_id }}</p>
                </div>
                
                <div class="warning">
                    <p><strong>⚠️ Security Notice:</strong></p>
                    <p>This API key will be stored on your router and will only work for this specific device.</p>
                </div>
                
                <form method="POST">
                    <label for="api_key">Enter your Claude API Key:</label>
                    <input type="text" id="api_key" name="api_key" placeholder="sk-ant-api03-..." required>
                    
                    <button type="submit">✅ Authorize Device</button>
                </form>
                
                <div class="help">
                    <p><strong>How to get your Claude API Key:</strong></p>
                    <ol>
                        <li>Visit <a href="https://console.anthropic.com/" target="_blank">Anthropic Console</a></li>
                        <li>Sign in or create an account</li>
                        <li>Go to API Keys section</li>
                        <li>Create a new API key or use an existing one</li>
                        <li>Copy the key (starts with <code>sk-ant-</code>)</li>
                        <li>Paste it above and click "Authorize Device"</li>
                    </ol>
                </div>
            </div>
        </body>
        </html>
        """, router_identity=auth_info.get('router_identity', 'Unknown'), router_id=auth_info.get('router_id', 'Unknown'))
        
    except Exception as e:
        logger.error(f"Error in device_authorization_page: {e}")
        return f"Error: {str(e)}", 500


@app.route('/auth/poll', methods=['POST'])
def poll_device_authorization():
    """Poll for device authorization status - router checks if API key is available."""
    try:
        data = request.get_json() or {}
        device_code = data.get('device_code', '')
        
        if not device_code:
            return jsonify({
                "success": False,
                "error": "Missing 'device_code' in request"
            }), 400
        
        # Cleanup expired codes
        cleanup_expired_authorizations()
        
        # Get authorization info
        with AUTHORIZATION_LOCK:
            auth_info = DEVICE_AUTHORIZATIONS.get(device_code)
        
        if not auth_info:
            return jsonify({
                "success": False,
                "error": "Invalid or expired device code",
                "authorized": False
            }), 404
        
        # Check if authorized
        if auth_info.get('api_key') and auth_info.get('status') == 'authorized':
            api_key = auth_info['api_key']
            
            # Optionally remove from storage after retrieval (one-time use)
            # Or keep it for re-authorization
            # del DEVICE_AUTHORIZATIONS[device_code]
            
            logger.info(f"Device authorization retrieved: router_id={auth_info.get('router_id')}, device_code={device_code[:8]}...")
            
            return jsonify({
                "success": True,
                "authorized": True,
                "api_key": api_key,
                "router_id": auth_info.get('router_id'),
                "router_identity": auth_info.get('router_identity'),
                "authorized_at": auth_info.get('authorized_at').isoformat() if auth_info.get('authorized_at') else None
            })
        else:
            return jsonify({
                "success": True,
                "authorized": False,
                "status": auth_info.get('status', 'pending'),
                "message": "Authorization pending - user has not yet authorized this device"
            })
        
    except Exception as e:
        logger.error(f"Error in poll_device_authorization: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/suggest-error-fix', methods=['POST'])
def suggest_error_fix():
    """Analyze command error and suggest fixes using Claude."""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "Missing request body"
            }), 400
        
        original_command = data.get('original_command', '')
        error_message = data.get('error_message', '')
        command_output = data.get('command_output', '')
        
        if not original_command:
            return jsonify({
                "success": False,
                "error": "Missing 'original_command' in request body"
            }), 400
        
        # Build prompt for Claude to analyze the error
        system_prompt = """You are a RouterOS command expert assistant. Your task is to analyze command errors and suggest fixes.

When a RouterOS command fails, analyze:
1. The original command that was attempted
2. The error message or output
3. Common RouterOS syntax issues

Provide helpful suggestions including:
- What went wrong
- The corrected command (if possible)
- Alternative approaches if the command cannot be fixed
- Tips for avoiding similar errors

Be concise and actionable. Focus on RouterOS-specific syntax and common mistakes."""

        user_prompt = f"""A RouterOS command failed. Please analyze and suggest a fix.

Original Command:
{original_command}

Error Message:
{error_message}

Command Output:
{command_output}

Please provide:
1. What went wrong
2. The corrected command (if applicable)
3. Any alternative approaches

Format your response clearly with the corrected command if possible."""

        # Call Claude API with custom system prompt for error analysis
        suggestion = call_claude_api(user_prompt, custom_system_prompt=system_prompt)
        
        if not suggestion:
            return jsonify({
                "success": False,
                "error": "Failed to get suggestion from Claude API"
            }), 500
        
        # Check if Claude returned an error
        if suggestion.startswith("ERROR:"):
            return jsonify({
                "success": False,
                "error": suggestion.replace("ERROR:", "").strip()
            }), 500
        
        return jsonify({
            "success": True,
            "suggestion": suggestion,
            "original_command": original_command,
            "error_message": error_message
        })
        
    except Exception as e:
        logger.error(f"Error in suggest_error_fix endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


if __name__ == '__main__':
    # Load knowledge base
    load_knowledge_base()
    
    # Check configuration
    if not CONFIG['claude_api_key'] and CONFIG['claude_mode'] == 'anthropic':
        logger.warning("Claude API key not configured. Set CLAUDE_API_KEY environment variable.")
    
    logger.info(f"Starting Claude Code Relay Node on {CONFIG['host']}:{CONFIG['port']}")
    if CONFIG['enable_cloud']:
        logger.info(f"Cloud access enabled on port {CONFIG['cloud_port']}")
    logger.info(f"Mode: {CONFIG['claude_mode']}")
    logger.info(f"Max workers: {CONFIG['max_workers']}")
    
    # Start main service
    if CONFIG['enable_cloud']:
        # Start cloud server on separate port
        import threading
        cloud_app = Flask(__name__)
        CORS(cloud_app)
        
        # Copy routes to cloud app
        cloud_app.add_url_rule('/health', 'health_check', health_check, methods=['GET'])
        cloud_app.add_url_rule('/process-command', 'process_command', process_command, methods=['POST'])
        cloud_app.add_url_rule('/suggest-error-fix', 'suggest_error_fix', suggest_error_fix, methods=['POST'])
        cloud_app.add_url_rule('/handshake', 'handshake', handshake, methods=['POST'])
        cloud_app.add_url_rule('/auth/request', 'request_device_authorization', request_device_authorization, methods=['POST'])
        cloud_app.add_url_rule('/auth/<device_code>', 'device_authorization_page', device_authorization_page, methods=['GET', 'POST'])
        cloud_app.add_url_rule('/auth/poll', 'poll_device_authorization', poll_device_authorization, methods=['POST'])
        
        def run_cloud_server():
            cloud_app.run(
                host=CONFIG['host'],
                port=CONFIG['cloud_port'],
                threaded=True,
                debug=False
            )
        
        cloud_thread = threading.Thread(target=run_cloud_server, daemon=True)
        cloud_thread.start()
        logger.info(f"Cloud server started on port {CONFIG['cloud_port']}")
    
    app.run(
        host=CONFIG['host'],
        port=CONFIG['port'],
        threaded=True,
        debug=False
    )

