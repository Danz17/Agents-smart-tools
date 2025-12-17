#!/usr/bin/env python3
"""
MikroTik RouterOS API Examples
Various examples of using the RouterOS API to interact with your router
"""

from routeros_api import connect

# Connection parameters
HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def example_get_ip_addresses(connection):
    """Get all IP addresses configured on the router"""
    print("\n=== IP Addresses ===")
    resource = connection.get_resource('/ip/address')
    addresses = resource.get()
    for addr in addresses:
        print(f"Interface: {addr.get('interface', 'N/A')}, "
              f"Address: {addr.get('address', 'N/A')}, "
              f"Network: {addr.get('network', 'N/A')}")

def example_get_interfaces(connection):
    """Get all network interfaces"""
    print("\n=== Network Interfaces ===")
    resource = connection.get_resource('/interface')
    interfaces = resource.get()
    for iface in interfaces:
        print(f"Name: {iface.get('name', 'N/A')}, "
              f"Type: {iface.get('type', 'N/A')}, "
              f"Status: {iface.get('running', 'N/A')}")

def example_get_routes(connection):
    """Get routing table"""
    print("\n=== Routing Table ===")
    resource = connection.get_resource('/ip/route')
    routes = resource.get()
    for route in routes[:10]:  # Show first 10 routes
        print(f"Destination: {route.get('dst-address', 'N/A')}, "
              f"Gateway: {route.get('gateway', 'N/A')}, "
              f"Distance: {route.get('distance', 'N/A')}")

def example_get_dhcp_leases(connection):
    """Get DHCP server leases"""
    print("\n=== DHCP Leases ===")
    resource = connection.get_resource('/ip/dhcp-server/lease')
    leases = resource.get()
    for lease in leases:
        print(f"Address: {lease.get('address', 'N/A')}, "
              f"MAC: {lease.get('mac-address', 'N/A')}, "
              f"Host: {lease.get('host-name', 'N/A')}, "
              f"Status: {lease.get('status', 'N/A')}")

def example_get_firewall_rules(connection):
    """Get firewall filter rules"""
    print("\n=== Firewall Rules (first 5) ===")
    resource = connection.get_resource('/ip/firewall/filter')
    rules = resource.get()
    for rule in rules[:5]:
        print(f"Chain: {rule.get('chain', 'N/A')}, "
              f"Action: {rule.get('action', 'N/A')}, "
              f"Comment: {rule.get('comment', 'N/A')}")

def example_add_static_route(connection, dst, gateway):
    """Add a static route"""
    print(f"\n=== Adding Static Route ===")
    resource = connection.get_resource('/ip/route')
    try:
        result = resource.add(dst=dst, gateway=gateway)
        print(f"[OK] Route added: {dst} via {gateway}")
        return result
    except Exception as e:
        print(f"[ERROR] Failed to add route: {str(e)}")
        return None

def example_get_system_info(connection):
    """Get system information"""
    print("\n=== System Information ===")
    
    # Identity
    resource = connection.get_resource('/system/identity')
    identity = resource.get()
    if identity:
        print(f"Router Name: {identity[0].get('name', 'N/A')}")
    
    # Resources
    resource = connection.get_resource('/system/resource')
    resources = resource.get()
    if resources:
        res = resources[0]
        print(f"CPU: {res.get('cpu', 'N/A')}")
        print(f"Uptime: {res.get('uptime', 'N/A')}")
        print(f"Version: {res.get('version', 'N/A')}")
        print(f"Free Memory: {res.get('free-memory', 'N/A')}")
        print(f"Total Memory: {res.get('total-memory', 'N/A')}")

def main():
    """Main function to demonstrate RouterOS API usage"""
    try:
        print(f"Connecting to {HOST}...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT)
        print("[OK] Connected successfully!\n")
        
        # Run examples
        example_get_system_info(connection)
        example_get_interfaces(connection)
        example_get_ip_addresses(connection)
        example_get_routes(connection)
        example_get_dhcp_leases(connection)
        example_get_firewall_rules(connection)
        
        # Example: Add a route (commented out to avoid accidental changes)
        # example_add_static_route(connection, "192.168.100.0/24", "10.1.1.254")
        
        print("\n[OK] Examples completed!")
        connection.disconnect()
        
    except Exception as e:
        print(f"[ERROR] Connection failed: {str(e)}")
        print("\nMake sure:")
        print("1. RouterOS API service is enabled (IP > Services > api)")
        print("2. Port 8728 is accessible")
        print("3. Username and password are correct")

if __name__ == "__main__":
    main()


