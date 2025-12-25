#!/usr/bin/env python3
"""
TxMTC Multi-Router Relay Service
================================
Central hub for managing multiple MikroTik routers via REST API.

GitHub: https://github.com/Danz17/Agents-smart-tools
Author: Phenix | Crafted with love & frustration
"""

import os
import json
import logging
import hashlib
import time
from datetime import datetime
from functools import wraps
from typing import Dict, List, Optional, Any

from flask import Flask, request, jsonify
from cryptography.fernet import Fernet
import routeros_api

# ============================================================================
# CONFIGURATION
# ============================================================================

app = Flask(__name__)
app.config['JSON_SORT_KEYS'] = False

# Logging setup
logging.basicConfig(
  level=logging.INFO,
  format='%(asctime)s [%(levelname)s] %(message)s',
  datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configuration file path
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')
ROUTERS_FILE = os.path.join(os.path.dirname(__file__), 'routers.enc')

# ============================================================================
# ENCRYPTION MANAGER
# ============================================================================

class EncryptionManager:
  """Handles encryption/decryption of sensitive data using Fernet."""

  def __init__(self, key_file: str = None):
    self.key_file = key_file or os.path.join(
      os.path.dirname(__file__), '.encryption_key'
    )
    self.fernet = self._load_or_create_key()

  def _load_or_create_key(self) -> Fernet:
    """Load existing key or create new one."""
    if os.path.exists(self.key_file):
      with open(self.key_file, 'rb') as f:
        key = f.read()
    else:
      key = Fernet.generate_key()
      with open(self.key_file, 'wb') as f:
        f.write(key)
      os.chmod(self.key_file, 0o600)
      logger.info("Generated new encryption key")
    return Fernet(key)

  def encrypt(self, data: str) -> str:
    """Encrypt a string."""
    return self.fernet.encrypt(data.encode()).decode()

  def decrypt(self, data: str) -> str:
    """Decrypt a string."""
    return self.fernet.decrypt(data.encode()).decode()


# ============================================================================
# ROUTER MANAGER
# ============================================================================

class RouterManager:
  """Manages router connections and command execution."""

  def __init__(self, encryption: EncryptionManager):
    self.encryption = encryption
    self.routers: Dict[str, dict] = {}
    self.connections: Dict[str, routeros_api.RouterOsApiPool] = {}
    self._load_routers()

  def _load_routers(self):
    """Load routers from encrypted file."""
    if os.path.exists(ROUTERS_FILE):
      try:
        with open(ROUTERS_FILE, 'r') as f:
          encrypted_data = f.read()
        if encrypted_data:
          decrypted = self.encryption.decrypt(encrypted_data)
          self.routers = json.loads(decrypted)
          logger.info(f"Loaded {len(self.routers)} routers")
      except Exception as e:
        logger.error(f"Failed to load routers: {e}")
        self.routers = {}

  def _save_routers(self):
    """Save routers to encrypted file."""
    try:
      data = json.dumps(self.routers)
      encrypted = self.encryption.encrypt(data)
      with open(ROUTERS_FILE, 'w') as f:
        f.write(encrypted)
      os.chmod(ROUTERS_FILE, 0o600)
    except Exception as e:
      logger.error(f"Failed to save routers: {e}")
      raise

  def add_router(
    self,
    name: str,
    host: str,
    username: str,
    password: str,
    port: int = 8728,
    use_ssl: bool = False,
    description: str = ""
  ) -> dict:
    """Add a new router to the registry."""
    if name in self.routers:
      raise ValueError(f"Router '{name}' already exists")

    self.routers[name] = {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'use_ssl': use_ssl,
      'description': description,
      'added_at': datetime.now().isoformat(),
      'last_seen': None
    }
    self._save_routers()
    logger.info(f"Added router: {name} ({host})")
    return {'name': name, 'host': host, 'status': 'added'}

  def remove_router(self, name: str) -> dict:
    """Remove a router from the registry."""
    if name not in self.routers:
      raise ValueError(f"Router '{name}' not found")

    # Close any existing connection
    if name in self.connections:
      try:
        self.connections[name].disconnect()
      except:
        pass
      del self.connections[name]

    del self.routers[name]
    self._save_routers()
    logger.info(f"Removed router: {name}")
    return {'name': name, 'status': 'removed'}

  def get_router(self, name: str) -> Optional[dict]:
    """Get router info (without password)."""
    if name not in self.routers:
      return None

    router = self.routers[name].copy()
    router['password'] = '********'
    router['name'] = name
    return router

  def list_routers(self) -> List[dict]:
    """List all routers with status."""
    result = []
    for name, router in self.routers.items():
      info = {
        'name': name,
        'host': router['host'],
        'port': router['port'],
        'description': router.get('description', ''),
        'last_seen': router.get('last_seen'),
        'online': self._check_online(name)
      }
      result.append(info)
    return result

  def _check_online(self, name: str) -> bool:
    """Quick check if router is reachable."""
    try:
      conn = self._get_connection(name, timeout=3)
      return conn is not None
    except:
      return False

  def _get_connection(
    self,
    name: str,
    timeout: int = 10
  ) -> routeros_api.RouterOsApiPool:
    """Get or create connection to router."""
    if name not in self.routers:
      raise ValueError(f"Router '{name}' not found")

    router = self.routers[name]

    # Try to reuse existing connection
    if name in self.connections:
      try:
        # Test connection
        api = self.connections[name].get_api()
        api.get_resource('/system/identity').get()
        return self.connections[name]
      except:
        # Connection stale, remove it
        try:
          self.connections[name].disconnect()
        except:
          pass
        del self.connections[name]

    # Create new connection
    try:
      pool = routeros_api.RouterOsApiPool(
        host=router['host'],
        username=router['username'],
        password=router['password'],
        port=router['port'],
        use_ssl=router.get('use_ssl', False),
        ssl_verify=False,
        plaintext_login=True
      )
      self.connections[name] = pool

      # Update last seen
      self.routers[name]['last_seen'] = datetime.now().isoformat()
      self._save_routers()

      logger.info(f"Connected to router: {name}")
      return pool
    except Exception as e:
      logger.error(f"Connection failed to {name}: {e}")
      raise ConnectionError(f"Failed to connect to {name}: {str(e)}")

  def execute_command(
    self,
    name: str,
    command: str,
    args: dict = None
  ) -> dict:
    """Execute a RouterOS command on specified router."""
    start_time = time.time()

    try:
      pool = self._get_connection(name)
      api = pool.get_api()

      # Parse command path (e.g., "/ip/address" or "/system/identity")
      resource_path = command.rstrip('/')

      # Determine operation from command or args
      operation = 'get'
      if args:
        operation = args.pop('_operation', 'get')

      resource = api.get_resource(resource_path)

      if operation == 'get':
        result = resource.get(**(args or {}))
      elif operation == 'add':
        result = resource.add(**(args or {}))
      elif operation == 'set':
        result = resource.set(**(args or {}))
      elif operation == 'remove':
        result = resource.remove(**(args or {}))
      elif operation == 'call':
        # For commands like /system/reboot
        result = resource.call(args.get('_method', 'print'), args or {})
      else:
        result = resource.get(**(args or {}))

      elapsed = round((time.time() - start_time) * 1000, 2)

      return {
        'success': True,
        'router': name,
        'command': command,
        'result': result,
        'elapsed_ms': elapsed
      }

    except Exception as e:
      elapsed = round((time.time() - start_time) * 1000, 2)
      logger.error(f"Command failed on {name}: {e}")
      return {
        'success': False,
        'router': name,
        'command': command,
        'error': str(e),
        'elapsed_ms': elapsed
      }

  def get_status(self, name: str) -> dict:
    """Get detailed status of a router."""
    try:
      pool = self._get_connection(name, timeout=5)
      api = pool.get_api()

      # Get identity
      identity = api.get_resource('/system/identity').get()
      identity_name = identity[0]['name'] if identity else 'Unknown'

      # Get resource usage
      resources = api.get_resource('/system/resource').get()
      resource = resources[0] if resources else {}

      # Get RouterOS version
      version = resource.get('version', 'Unknown')
      uptime = resource.get('uptime', 'Unknown')
      cpu_load = resource.get('cpu-load', 0)
      free_memory = resource.get('free-memory', 0)
      total_memory = resource.get('total-memory', 1)

      # Memory percentage
      mem_percent = round((1 - int(free_memory) / int(total_memory)) * 100, 1)

      return {
        'success': True,
        'router': name,
        'online': True,
        'identity': identity_name,
        'version': version,
        'uptime': uptime,
        'cpu_load': f"{cpu_load}%",
        'memory_used': f"{mem_percent}%",
        'last_checked': datetime.now().isoformat()
      }

    except Exception as e:
      return {
        'success': False,
        'router': name,
        'online': False,
        'error': str(e),
        'last_checked': datetime.now().isoformat()
      }

  def execute_on_all(self, command: str, args: dict = None) -> List[dict]:
    """Execute command on all registered routers."""
    results = []
    for name in self.routers:
      result = self.execute_command(name, command, args.copy() if args else None)
      results.append(result)
    return results


# ============================================================================
# AUTHENTICATION
# ============================================================================

def load_config() -> dict:
  """Load configuration file."""
  if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, 'r') as f:
      return json.load(f)
  return {'api_token': None, 'listen_host': '0.0.0.0', 'listen_port': 5001}


def require_auth(f):
  """Decorator for API authentication."""
  @wraps(f)
  def decorated(*args, **kwargs):
    config = load_config()
    token = config.get('api_token')

    if token:
      auth_header = request.headers.get('Authorization')
      if not auth_header or auth_header != f"Bearer {token}":
        return jsonify({'error': 'Unauthorized'}), 401

    return f(*args, **kwargs)
  return decorated


# ============================================================================
# INITIALIZE MANAGERS
# ============================================================================

encryption = EncryptionManager()
router_manager = RouterManager(encryption)


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.route('/health', methods=['GET'])
def health_check():
  """Health check endpoint."""
  return jsonify({
    'status': 'healthy',
    'service': 'TxMTC Multi-Router Relay',
    'version': '1.0.0',
    'routers_registered': len(router_manager.routers),
    'timestamp': datetime.now().isoformat()
  })


@app.route('/routers', methods=['GET'])
@require_auth
def list_routers():
  """List all registered routers."""
  routers = router_manager.list_routers()
  return jsonify({
    'success': True,
    'count': len(routers),
    'routers': routers
  })


@app.route('/routers', methods=['POST'])
@require_auth
def add_router():
  """Add a new router."""
  data = request.get_json()

  if not data:
    return jsonify({'error': 'No data provided'}), 400

  required = ['name', 'host', 'username', 'password']
  missing = [f for f in required if f not in data]
  if missing:
    return jsonify({'error': f'Missing fields: {", ".join(missing)}'}), 400

  try:
    result = router_manager.add_router(
      name=data['name'],
      host=data['host'],
      username=data['username'],
      password=data['password'],
      port=data.get('port', 8728),
      use_ssl=data.get('use_ssl', False),
      description=data.get('description', '')
    )
    return jsonify({'success': True, **result}), 201
  except ValueError as e:
    return jsonify({'error': str(e)}), 409
  except Exception as e:
    return jsonify({'error': str(e)}), 500


@app.route('/routers/<name>', methods=['GET'])
@require_auth
def get_router(name: str):
  """Get router details."""
  router = router_manager.get_router(name)
  if not router:
    return jsonify({'error': f"Router '{name}' not found"}), 404
  return jsonify({'success': True, 'router': router})


@app.route('/routers/<name>', methods=['DELETE'])
@require_auth
def remove_router(name: str):
  """Remove a router."""
  try:
    result = router_manager.remove_router(name)
    return jsonify({'success': True, **result})
  except ValueError as e:
    return jsonify({'error': str(e)}), 404
  except Exception as e:
    return jsonify({'error': str(e)}), 500


@app.route('/routers/<name>/status', methods=['GET'])
@require_auth
def get_router_status(name: str):
  """Get detailed router status."""
  if name not in router_manager.routers:
    return jsonify({'error': f"Router '{name}' not found"}), 404

  status = router_manager.get_status(name)
  return jsonify(status)


@app.route('/routers/<name>/execute', methods=['POST'])
@require_auth
def execute_command(name: str):
  """Execute command on a router."""
  if name not in router_manager.routers:
    return jsonify({'error': f"Router '{name}' not found"}), 404

  data = request.get_json()
  if not data or 'command' not in data:
    return jsonify({'error': 'No command provided'}), 400

  result = router_manager.execute_command(
    name=name,
    command=data['command'],
    args=data.get('args')
  )

  status_code = 200 if result['success'] else 500
  return jsonify(result), status_code


@app.route('/routers/all/execute', methods=['POST'])
@require_auth
def execute_on_all():
  """Execute command on all routers."""
  data = request.get_json()
  if not data or 'command' not in data:
    return jsonify({'error': 'No command provided'}), 400

  results = router_manager.execute_on_all(
    command=data['command'],
    args=data.get('args')
  )

  success_count = sum(1 for r in results if r['success'])

  return jsonify({
    'success': success_count == len(results),
    'total': len(results),
    'successful': success_count,
    'failed': len(results) - success_count,
    'results': results
  })


@app.route('/routers/all/status', methods=['GET'])
@require_auth
def get_all_status():
  """Get status of all routers."""
  statuses = []
  for name in router_manager.routers:
    status = router_manager.get_status(name)
    statuses.append(status)

  online_count = sum(1 for s in statuses if s.get('online'))

  return jsonify({
    'success': True,
    'total': len(statuses),
    'online': online_count,
    'offline': len(statuses) - online_count,
    'routers': statuses
  })


# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(404)
def not_found(e):
  return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def server_error(e):
  return jsonify({'error': 'Internal server error'}), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
  config = load_config()

  host = config.get('listen_host', '0.0.0.0')
  port = config.get('listen_port', 5001)

  logger.info(f"Starting TxMTC Multi-Router Relay on {host}:{port}")
  logger.info(f"Registered routers: {len(router_manager.routers)}")

  if not config.get('api_token'):
    logger.warning("No API token configured - endpoints are unprotected!")

  app.run(host=host, port=port, debug=False, threaded=True)
