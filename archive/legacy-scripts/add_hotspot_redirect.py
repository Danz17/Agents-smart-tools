#!/usr/bin/env python3
"""
Add Hotspot Redirect Rules
Automatically adds the required NAT rules to force users to hotspot login page
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def add_hotspot_redirect_rules():
    """Add NAT redirect rules for hotspot"""
    try:
        print(f"Connecting to {HOST}...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        print("[OK] Connected\n")
        
        # Get hotspot info
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        if not hotspots:
            print("[ERROR] No hotspot servers found!")
            return
        
        hotspot = hotspots[0]
        hotspot_interface = hotspot.get('interface', '')
        hotspot_name = hotspot.get('name', 'N/A')
        
        print(f"Hotspot: {hotspot_name}")
        print(f"Interface: {hotspot_interface}\n")
        
        # Check if redirect rules already exist
        print("Checking for existing redirect rules...")
        resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = resource.get()
        
        existing_rules = []
        for rule in nat_rules:
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            in_interface = rule.get('in-interface', '')
            dst_port = rule.get('dst-port', '')
            comment = rule.get('comment', '')
            
            if (chain == 'dstnat' and action == 'redirect' and 
                in_interface == hotspot_interface and 
                ('hotspot' in comment.lower() or dst_port in ['80', '443'])):
                existing_rules.append(rule)
        
        if existing_rules:
            print(f"Found {len(existing_rules)} existing redirect rule(s)")
            for rule in existing_rules:
                disabled = rule.get('disabled', 'no')
                print(f"  Rule ID: {rule.get('.id', 'N/A')}, Dst Port: {rule.get('dst-port', 'N/A')}, Disabled: {disabled}")
                if disabled == 'true':
                    print(f"    [FIXING] Enabling disabled rule...")
                    resource.set(id=rule.get('.id'), disabled='no')
                    print(f"    [OK] Rule enabled")
        else:
            print("No existing redirect rules found. Creating new ones...\n")
            
            # Add HTTP redirect rule
            print("Adding HTTP redirect rule (port 80)...")
            try:
                result = resource.add(
                    chain='dstnat',
                    action='redirect',
                    in_interface=hotspot_interface,
                    protocol='tcp',
                    dst_port='80',
                    to_ports='80',
                    comment='hotspot-http-redirect'
                )
                print("[OK] HTTP redirect rule added")
            except Exception as e:
                print(f"[ERROR] Failed to add HTTP rule: {str(e)}")
            
            # Add HTTPS redirect rule (optional but recommended)
            print("Adding HTTPS redirect rule (port 443)...")
            try:
                result = resource.add(
                    chain='dstnat',
                    action='redirect',
                    in_interface=hotspot_interface,
                    protocol='tcp',
                    dst_port='443',
                    to_ports='80',
                    comment='hotspot-https-redirect'
                )
                print("[OK] HTTPS redirect rule added")
            except Exception as e:
                print(f"[WARNING] Failed to add HTTPS rule: {str(e)}")
                print("This is optional - HTTP redirect should be sufficient")
        
        print("\n" + "=" * 70)
        print("[SUCCESS] Hotspot redirect rules configured!")
        print("=" * 70)
        print("\nUsers connecting to the hotspot should now be redirected to the login page.")
        print("Test by connecting a device to the WiFi and opening a web browser.")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    add_hotspot_redirect_rules()

