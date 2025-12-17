#!/usr/bin/env python3
"""
Fix MikroTik Hotspot Configuration
Fixes common issues preventing hotspot login redirect
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def fix_hotspot():
    """Fix hotspot configuration issues"""
    try:
        print(f"Connecting to {HOST}...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        print("[OK] Connected\n")
        
        print("=" * 70)
        print("CHECKING HOTSPOT CONFIGURATION")
        print("=" * 70)
        
        # Get hotspot info
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        if not hotspots:
            print("[ERROR] No hotspot servers found!")
            return
        
        hotspot = hotspots[0]  # Get first hotspot
        hotspot_name = hotspot.get('name', 'N/A')
        hotspot_interface = hotspot.get('interface', 'N/A')
        
        print(f"\nHotspot: {hotspot_name}")
        print(f"Interface: {hotspot_interface}")
        
        # Check NAT rules for hotspot redirect
        print("\n\nChecking NAT rules for hotspot redirect...")
        resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = resource.get()
        
        # Look for hotspot redirect rules
        redirect_rules = []
        for rule in nat_rules:
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            comment = rule.get('comment', '').lower()
            disabled = rule.get('disabled', 'no')
            
            # Check if this is a hotspot redirect rule
            if (chain == 'dstnat' and action == 'redirect' and 
                ('hotspot' in comment or 'login' in comment or rule.get('dst-port', '') == '80')):
                redirect_rules.append(rule)
                print(f"\nFound redirect rule: {rule.get('.id', 'N/A')}")
                print(f"  Chain: {chain}")
                print(f"  Action: {action}")
                print(f"  Dst Port: {rule.get('dst-port', 'N/A')}")
                print(f"  To Ports: {rule.get('to-ports', 'N/A')}")
                print(f"  In Interface: {rule.get('in-interface', 'N/A')}")
                print(f"  Disabled: {disabled}")
                
                if disabled == 'true':
                    print(f"  [ISSUE] Rule is DISABLED!")
        
        # Check if we need to create hotspot redirect rules
        if not redirect_rules:
            print("\n[ISSUE] No hotspot redirect NAT rules found!")
            print("Hotspot needs NAT rules to redirect HTTP traffic to login page")
            print("\nRequired NAT rules:")
            print("1. Redirect HTTP (port 80) to hotspot login")
            print("2. Redirect HTTPS (port 443) to hotspot login (optional)")
            
            # Check if user wants to create the rules
            print("\nTo fix this, you need to add NAT rules:")
            print(f"  /ip firewall nat add chain=dstnat in-interface={hotspot_interface} protocol=tcp dst-port=80 action=redirect to-ports=80")
            print(f"  /ip firewall nat add chain=dstnat in-interface={hotspot_interface} protocol=tcp dst-port=443 action=redirect to-ports=80")
        
        # Check firewall filter rules
        print("\n\nChecking Firewall Filter Rules...")
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # Check for rules blocking hotspot traffic
        blocking_rules = []
        for rule in filter_rules:
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            in_interface = rule.get('in-interface', '')
            disabled = rule.get('disabled', 'no')
            
            if (in_interface == hotspot_interface and 
                action in ['drop', 'reject'] and 
                disabled == 'no'):
                blocking_rules.append(rule)
                print(f"\nFound potentially blocking rule: {rule.get('.id', 'N/A')}")
                print(f"  Chain: {chain}")
                print(f"  Action: {action}")
                print(f"  In Interface: {in_interface}")
                print(f"  Comment: {rule.get('comment', 'N/A')}")
        
        if blocking_rules:
            print(f"\n[WARNING] Found {len(blocking_rules)} rules that might block hotspot traffic")
        else:
            print("[OK] No obvious blocking rules found")
        
        # Check IP pool
        print("\n\nChecking IP Pool...")
        pool_name = hotspot.get('address-pool', 'N/A')
        if pool_name and pool_name != 'N/A':
            resource = connection.get_resource('/ip/pool')
            pools = resource.get()
            pool_found = False
            for pool in pools:
                if pool.get('name', '') == pool_name:
                    pool_found = True
                    print(f"[OK] IP Pool '{pool_name}' exists")
                    print(f"  Ranges: {pool.get('ranges', 'N/A')}")
                    break
            if not pool_found:
                print(f"[ISSUE] IP Pool '{pool_name}' not found!")
        
        # Summary
        print("\n\n" + "=" * 70)
        print("SUMMARY AND RECOMMENDATIONS")
        print("=" * 70)
        
        issues_found = []
        if not redirect_rules:
            issues_found.append("Missing NAT redirect rules for hotspot")
        if any(r.get('disabled', 'no') == 'true' for r in redirect_rules):
            issues_found.append("Hotspot NAT redirect rules are disabled")
        if blocking_rules:
            issues_found.append("Firewall rules may be blocking hotspot traffic")
        
        if issues_found:
            print("\n[ISSUES FOUND]:")
            for i, issue in enumerate(issues_found, 1):
                print(f"  {i}. {issue}")
            
            print("\n[RECOMMENDED FIX]:")
            print("Run these commands in RouterOS terminal:")
            print()
            print(f"# Enable hotspot redirect for HTTP")
            print(f"/ip firewall nat add chain=dstnat in-interface={hotspot_interface} protocol=tcp dst-port=80 action=redirect to-ports=80 comment=\"hotspot-http-redirect\"")
            print()
            print(f"# Enable hotspot redirect for HTTPS (optional)")
            print(f"/ip firewall nat add chain=dstnat in-interface={hotspot_interface} protocol=tcp dst-port=443 action=redirect to-ports=80 comment=\"hotspot-https-redirect\"")
            print()
            print("# If you have disabled NAT rules, enable them:")
            print("/ip firewall nat enable [find comment~\"hotspot\"]")
        else:
            print("\n[OK] Basic hotspot configuration looks correct")
            print("If users still aren't redirected, check:")
            print("  1. DNS settings on hotspot interface")
            print("  2. Hotspot profile settings")
            print("  3. User authentication method")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    fix_hotspot()

