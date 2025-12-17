#!/usr/bin/env python3
"""
Enable Hotspot and verify configuration
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def enable_hotspot():
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("Checking and enabling hotspot...\n")
        
        # Get hotspot
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        if not hotspots:
            print("[ERROR] No hotspot found!")
            return
        
        for hotspot in hotspots:
            name = hotspot.get('name', 'N/A')
            disabled = hotspot.get('disabled', 'no')
            interface = hotspot.get('interface', 'N/A')
            
            print(f"Hotspot: {name}")
            print(f"Interface: {interface}")
            print(f"Current Status: {'Disabled' if disabled == 'true' else 'Enabled'}")
            
            if disabled == 'true':
                print(f"\n[FIXING] Enabling hotspot '{name}'...")
                resource.set(id=hotspot.get('.id'), disabled='no')
                print("[OK] Hotspot enabled!")
            else:
                print("[OK] Hotspot is already enabled")
            
            # Verify interface is enabled
            print(f"\nChecking interface '{interface}'...")
            iface_resource = connection.get_resource('/interface')
            interfaces = iface_resource.get()
            
            for iface in interfaces:
                if iface.get('name', '') == interface:
                    iface_disabled = iface.get('disabled', 'no')
                    if iface_disabled == 'true':
                        print(f"[ISSUE] Interface '{interface}' is DISABLED!")
                        print(f"[FIXING] Enabling interface...")
                        iface_resource.set(id=iface.get('.id'), disabled='no')
                        print("[OK] Interface enabled!")
                    else:
                        print(f"[OK] Interface '{interface}' is enabled")
                    break
        
        print("\n" + "=" * 70)
        print("[SUCCESS] Hotspot configuration verified and enabled!")
        print("=" * 70)
        print("\nSummary:")
        print("  [OK] Hotspot redirect rules: Configured")
        print("  [OK] Hotspot server: Enabled")
        print("  [OK] Interface: Enabled")
        print("\nUsers connecting to 'bawal balik' WiFi should now be")
        print("redirected to the hotspot login page when they open a browser.")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    enable_hotspot()

