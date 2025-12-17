#!/usr/bin/env python3
"""
MikroTik RouterOS API Connection Script
Connects to a MikroTik router using the RouterOS API protocol
"""

from routeros_api import connect
import sys

def connect_to_router():
    """Connect to MikroTik router using RouterOS API"""
    host = "10.1.1.1"
    username = "admin"
    password = "admin123"
    port = 8728  # Default RouterOS API port
    
    try:
        print(f"Connecting to {host}:{port}...")
        # Try with plaintext login first (some RouterOS versions require this)
        try:
            connection = connect(host, username=username, password=password, port=port, plaintext_login=True)
        except:
            # Fall back to standard login
            connection = connect(host, username=username, password=password, port=port)
        
        # Test connection by getting router identity
        resource = connection.get_resource('/system/identity')
        identity = resource.get()
        
        print(f"[OK] Successfully connected to {host}")
        print(f"Router Identity: {identity[0]['name'] if identity else 'Unknown'}")
        
        # Get routerboard info
        resource = connection.get_resource('/system/routerboard')
        rb_info = resource.get()
        if rb_info:
            print(f"RouterBoard Model: {rb_info[0].get('model', 'Unknown')}")
            print(f"Firmware: {rb_info[0].get('current-firmware', 'Unknown')}")
        
        # Get system resources
        resource = connection.get_resource('/system/resource')
        resources = resource.get()
        if resources:
            print(f"CPU: {resources[0].get('cpu', 'Unknown')}")
            print(f"Uptime: {resources[0].get('uptime', 'Unknown')}")
            print(f"Free Memory: {resources[0].get('free-memory', 'Unknown')}")
        
        return connection
        
    except Exception as e:
        error_msg = str(e)
        print(f"[ERROR] Connection failed: {error_msg}")
        
        if "invalid user name or password" in error_msg.lower() or "authentication" in error_msg.lower():
            print("\n[Authentication Error]")
            print("The API service is enabled, but authentication failed.")
            print("Possible issues:")
            print("  - Username or password is incorrect")
            print("  - User may not have API access enabled")
            print("  - API may require different credentials than SSH/Winbox")
            print("\nTo grant API access to a user:")
            print("  /user set admin api=yes")
            print("  (Run this in RouterOS terminal)")
        else:
            print("\nTroubleshooting tips:")
            print("1. Ensure RouterOS API service is enabled on the router")
            print("2. Check if port 8728 is accessible (firewall rules)")
            print("3. Verify username and password are correct")
        
        return None

if __name__ == "__main__":
    connection = connect_to_router()
    
    if connection:
        print("\nConnection established! You can now use the 'connection' object to interact with the router.")
        print("Example: connection.get_resource('/ip/address').get()")
        
        # Keep connection open for interactive use
        # Uncomment the following if you want to keep it open:
        # input("\nPress Enter to disconnect...")
        # connection.disconnect()
    else:
        sys.exit(1)

