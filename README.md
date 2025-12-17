# MikroTik RouterOS API Connection

This script connects to a MikroTik router using the RouterOS API protocol.

## Prerequisites

1. RouterOS API must be enabled on your MikroTik router
2. Python 3.6 or higher
3. Required Python package: `routeros-api`

## Installation

```bash
pip install -r requirements.txt
```

## Usage

```bash
python routeros_connect.py
```

## RouterOS API Configuration

To enable RouterOS API on your MikroTik router:

1. Connect via Winbox or WebFig
2. Go to **IP** → **Services**
3. Enable **API** service
4. Set the port (default is 8728, or 8729 for SSL)
5. Configure firewall rules if needed

## Connection Details

- Host: 10.1.1.1
- Username: admin
- Password: admin123
- Port: 8728 (default RouterOS API port)

## Example Usage in Code

```python
from routeros_api import connect

connection = connect('10.1.1.1', username='admin', password='admin123', port=8728)

# Get IP addresses
ip_addresses = connection.get_resource('/ip/address').get()

# Get interfaces
interfaces = connection.get_resource('/interface').get()

# Execute commands
connection.get_resource('/system/reboot').call('reboot')
```

