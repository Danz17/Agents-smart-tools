#!/usr/bin/env python3
"""
Check MikroTik Hotspot Configuration
Diagnoses why hotspot users aren't being forced to login page
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728
HOTSPOT_NAME = "bawal balik"

def check_hotspot_config():
    """Check hotspot configuration and identify issues"""
    try:
        print(f"Connecting to {HOST}...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        print("[OK] Connected\n")
        
        print("=" * 70)
        print("HOTSPOT CONFIGURATION DIAGNOSIS")
        print("=" * 70)
        
        # 1. Check IP Hotspot servers
        print("\n1. IP HOTSPOT SERVERS")
        print("-" * 70)
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        if not hotspots:
            print("[ERROR] No hotspot servers found!")
            return
        
        hotspot_found = False
        for hotspot in hotspots:
            name = hotspot.get('name', 'N/A')
            print(f"\nHotspot: {name}")
            print(f"  Interface: {hotspot.get('interface', 'N/A')}")
            print(f"  Address Pool: {hotspot.get('address-pool', 'N/A')}")
            print(f"  Profile: {hotspot.get('profile', 'N/A')}")
            print(f"  Disabled: {hotspot.get('disabled', 'no')}")
            
            if HOTSPOT_NAME.lower() in name.lower():
                hotspot_found = True
                if hotspot.get('disabled', 'no') == 'true':
                    print(f"  [ISSUE] Hotspot '{name}' is DISABLED!")
        
        if not hotspot_found:
            print(f"\n[WARNING] Hotspot with name containing '{HOTSPOT_NAME}' not found")
        
        # 2. Check Wireless interfaces
        print("\n\n2. WIRELESS INTERFACES")
        print("-" * 70)
        
        # Try different paths for wireless interfaces
        wireless = []
        try:
            resource = connection.get_resource('/interface/wireless')
            wireless = resource.get()
        except:
            try:
                # Try alternative path
                resource = connection.get_resource('/interface')
                all_interfaces = resource.get()
                wireless = [i for i in all_interfaces if i.get('type', '').lower() == 'wireless']
            except:
                pass
        
        if wireless:
            for wlan in wireless:
                name = wlan.get('name', 'N/A')
                ssid = wlan.get('ssid', 'N/A')
                disabled = wlan.get('disabled', 'no')
                print(f"\nInterface: {name}")
                print(f"  SSID: {ssid}")
                print(f"  Disabled: {disabled}")
                print(f"  Mode: {wlan.get('mode', 'N/A')}")
                print(f"  Security: {wlan.get('security-profile', 'N/A')}")
                
                if HOTSPOT_NAME.lower() in ssid.lower():
                    print(f"  [MATCH] This appears to be the '{HOTSPOT_NAME}' WiFi")
                    
                    # Check if this interface is bound to hotspot
                    for hotspot in hotspots:
                        if hotspot.get('interface', '') == name:
                            print(f"  [OK] Interface is bound to hotspot: {hotspot.get('name')}")
                        else:
                            print(f"  [ISSUE] Interface is NOT bound to any hotspot!")
        else:
            # Check all interfaces to find the hotspot interface
            print("Checking all interfaces for hotspot binding...")
            resource = connection.get_resource('/interface')
            all_interfaces = resource.get()
            
            for interface in all_interfaces:
                name = interface.get('name', 'N/A')
                interface_type = interface.get('type', 'N/A')
                disabled = interface.get('disabled', 'no')
                
                # Check if this interface is used by hotspot
                for hotspot in hotspots:
                    if hotspot.get('interface', '') == name:
                        print(f"\nInterface: {name} (Type: {interface_type})")
                        print(f"  [HOTSPOT] Bound to hotspot: {hotspot.get('name')}")
                        print(f"  Disabled: {disabled}")
                        
                        if disabled == 'true':
                            print(f"  [ISSUE] Interface is DISABLED!")
        
        # 3. Check Hotspot Profiles
        print("\n\n3. HOTSPOT PROFILES")
        print("-" * 70)
        resource = connection.get_resource('/ip/hotspot/profile')
        profiles = resource.get()
        
        for profile in profiles:
            name = profile.get('name', 'N/A')
            print(f"\nProfile: {name}")
            print(f"  HTTP Cookie: {profile.get('http-cookie-lifetime', 'N/A')}")
            print(f"  Login Timeout: {profile.get('login-timeout', 'N/A')}")
            print(f"  Idle Timeout: {profile.get('idle-timeout', 'N/A')}")
            print(f"  Keepalive Timeout: {profile.get('keepalive-timeout', 'N/A')}")
            print(f"  Status Auto-Refresh: {profile.get('status-autorefresh', 'N/A')}")
            print(f"  Shared Users: {profile.get('shared-users', 'N/A')}")
            print(f"  Open Status Page: {profile.get('open-status-page', 'N/A')}")
        
        # 4. Check Firewall NAT rules (for hotspot redirect)
        print("\n\n4. FIREWALL NAT RULES (Hotspot Redirect)")
        print("-" * 70)
        resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = resource.get()
        
        hotspot_nat_found = False
        for rule in nat_rules:
            comment = rule.get('comment', '').lower()
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            dst_port = rule.get('dst-port', '')
            
            if 'hotspot' in comment or action == 'redirect':
                hotspot_nat_found = True
                print(f"\nRule: {rule.get('.id', 'N/A')}")
                print(f"  Chain: {chain}")
                print(f"  Action: {action}")
                print(f"  Dst Port: {dst_port}")
                print(f"  Comment: {rule.get('comment', 'N/A')}")
                print(f"  Disabled: {rule.get('disabled', 'no')}")
                
                if rule.get('disabled', 'no') == 'true':
                    print(f"  [ISSUE] This NAT rule is DISABLED!")
        
        if not hotspot_nat_found:
            print("[WARNING] No hotspot NAT redirect rules found!")
            print("Hotspot typically needs NAT rules to redirect users to login page")
        
        # 5. Check Firewall Mangle rules (for hotspot marking)
        print("\n\n5. FIREWALL MANGLE RULES (Hotspot Marking)")
        print("-" * 70)
        resource = connection.get_resource('/ip/firewall/mangle')
        mangle_rules = resource.get()
        
        hotspot_mangle_found = False
        for rule in mangle_rules:
            comment = rule.get('comment', '').lower()
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            
            if 'hotspot' in comment or action == 'mark-packet':
                hotspot_mangle_found = True
                print(f"\nRule: {rule.get('.id', 'N/A')}")
                print(f"  Chain: {chain}")
                print(f"  Action: {action}")
                print(f"  Comment: {rule.get('comment', 'N/A')}")
                print(f"  Disabled: {rule.get('disabled', 'no')}")
        
        if not hotspot_mangle_found:
            print("[INFO] No hotspot mangle rules found (may be normal)")
        
        # 6. Check IP Hotspot Users
        print("\n\n6. ACTIVE HOTSPOT USERS")
        print("-" * 70)
        resource = connection.get_resource('/ip/hotspot/active')
        active_users = resource.get()
        
        if active_users:
            print(f"Found {len(active_users)} active user(s):")
            for user in active_users:
                print(f"  User: {user.get('user', 'N/A')}")
                print(f"    Server: {user.get('server', 'N/A')}")
                print(f"    Address: {user.get('address', 'N/A')}")
                print(f"    Uptime: {user.get('uptime', 'N/A')}")
        else:
            print("No active hotspot users")
        
        # 7. Check IP Hotspot IP Bindings
        print("\n\n7. HOTSPOT IP BINDINGS")
        print("-" * 70)
        resource = connection.get_resource('/ip/hotspot/ip-binding')
        bindings = resource.get()
        
        if bindings:
            print(f"Found {len(bindings)} IP binding(s):")
            for binding in bindings[:5]:  # Show first 5
                print(f"  MAC: {binding.get('mac-address', 'N/A')}")
                print(f"    Address: {binding.get('address', 'N/A')}")
                print(f"    Type: {binding.get('type', 'N/A')}")
                print(f"    To Address: {binding.get('to-address', 'N/A')}")
        else:
            print("No IP bindings configured")
        
        # Summary and recommendations
        print("\n\n" + "=" * 70)
        print("DIAGNOSIS SUMMARY")
        print("=" * 70)
        print("\nCommon issues that prevent hotspot login redirect:")
        print("1. Hotspot server is disabled")
        print("2. Wireless interface not bound to hotspot")
        print("3. Missing or disabled NAT redirect rules")
        print("4. Firewall blocking hotspot traffic")
        print("5. Wrong IP pool configuration")
        print("6. DNS not properly configured for hotspot")
        
        # Connection cleanup (routeros_api doesn't have disconnect method)
        try:
            connection.close()
        except:
            pass
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    check_hotspot_config()

