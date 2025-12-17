#!/usr/bin/env python3
"""
Check WiFi SSID configuration
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def check_wifi():
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("Checking WiFi interfaces and SSIDs...\n")
        
        # Get all interfaces
        resource = connection.get_resource('/interface')
        interfaces = resource.get()
        
        # Find WiFi interfaces
        wifi_interfaces = []
        for iface in interfaces:
            iface_type = iface.get('type', '').lower()
            if 'wifi' in iface_type or 'wireless' in iface_type:
                wifi_interfaces.append(iface.get('name', ''))
        
        print(f"Found WiFi interfaces: {wifi_interfaces}\n")
        
        # Try to get wireless info - RouterOS API path may vary
        # Check security profiles which often contain SSID info
        try:
            resource = connection.get_resource('/interface/wireless/security-profiles')
            profiles = resource.get()
            print("Security Profiles:")
            for profile in profiles:
                print(f"  {profile.get('name', 'N/A')}")
        except:
            pass
        
        # Check the hotspot interface specifically
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        for hotspot in hotspots:
            interface = hotspot.get('interface', '')
            print(f"\nHotspot: {hotspot.get('name', 'N/A')}")
            print(f"Bound to interface: {interface}")
            print(f"Status: {'Enabled' if hotspot.get('disabled', 'no') == 'no' else 'Disabled'}")
        
        print("\n[NOTE] To check the actual SSID name, you may need to:")
        print("  1. Connect to the router via Winbox")
        print("  2. Go to Wireless > Interfaces")
        print("  3. Check the SSID field for interface 'wifi2-hotspot'")
        print("\nOr check via RouterOS terminal:")
        print("  /interface wireless print")
        
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    check_wifi()

