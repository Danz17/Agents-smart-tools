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
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from typing import Dict, Optional, Any
from flask import Flask, request, jsonify
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
    'host': os.getenv('CLAUDE_RELAY_HOST', '0.0.0.0'),
    'claude_api_key': os.getenv('CLAUDE_API_KEY', ''),
    'claude_api_url': os.getenv('CLAUDE_API_URL', 'https://api.anthropic.com/v1/messages'),
    'claude_model': os.getenv('CLAUDE_MODEL', 'claude-3-5-sonnet-20241022'),
    'claude_mode': os.getenv('CLAUDE_MODE', 'anthropic'),  # 'anthropic' or 'local'
    'max_workers': int(os.getenv('MAX_WORKERS', 10)),
    'request_timeout': int(os.getenv('REQUEST_TIMEOUT', 30)),
    'knowledge_base_path': os.getenv('KNOWLEDGE_BASE_PATH', 'claude-relay-knowledge.json'),
}

# Thread pool for concurrent processing
executor = ThreadPoolExecutor(max_workers=CONFIG['max_workers'])

# Load RouterOS knowledge base
ROUTEROS_KNOWLEDGE = {}


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


def call_claude_api(user_message: str) -> Optional[str]:
    """Call Claude API to process smart command."""
    if not CONFIG['claude_api_key']:
        logger.error("Claude API key not configured")
        return None
    
    system_prompt = build_system_prompt()
    
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


def validate_routeros_command(command: str) -> tuple[bool, Optional[str]]:
    """Validate RouterOS command syntax and safety."""
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


if __name__ == '__main__':
    # Load knowledge base
    load_knowledge_base()
    
    # Check configuration
    if not CONFIG['claude_api_key'] and CONFIG['claude_mode'] == 'anthropic':
        logger.warning("Claude API key not configured. Set CLAUDE_API_KEY environment variable.")
    
    logger.info(f"Starting Claude Code Relay Node on {CONFIG['host']}:{CONFIG['port']}")
    logger.info(f"Mode: {CONFIG['claude_mode']}")
    logger.info(f"Max workers: {CONFIG['max_workers']}")
    
    app.run(
        host=CONFIG['host'],
        port=CONFIG['port'],
        threaded=True,
        debug=False
    )

