#!/usr/bin/env python3
"""
Analyze RouterOS Export and Fix Hotspot Login Issue
Based on the actual exported configuration
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def analyze_and_fix():
    """Analyze configuration and fix hotspot login enforcement"""
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("=" * 70)
        print("ANALYZING CONFIGURATION FROM EXPORT")
        print("=" * 70)
        
        # Key findings from export:
        # 1. Hotspot is on wifi2-hotspot (slave interface)
        # 2. wifi2-hotspot is bridged to bridge-hotspot
        # 3. bridge-hotspot is in LAN list
        # 4. There's a rule: accept chain=forward in-interface-list=LAN out-interface-list=WAN
        #    This allows ALL LAN traffic (including unauthenticated hotspot) to WAN!
        
        print("\n[ISSUE FOUND]")
        print("The firewall rule 'accept chain=forward in-interface-list=LAN out-interface-list=WAN'")
        print("allows ALL LAN traffic (including unauthenticated hotspot users) to access WAN.")
        print("This bypasses hotspot authentication!")
        
        # Get current firewall rules
        print("\n1. Checking Current Firewall Rules...")
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # Find the problematic rule
        problematic_rule = None
        for rule in filter_rules:
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            in_interface_list = rule.get('in-interface-list', '')
            out_interface_list = rule.get('out-interface-list', '')
            
            if (chain == 'forward' and 
                action == 'accept' and 
                in_interface_list == 'LAN' and 
                out_interface_list == 'WAN' and
                not rule.get('hotspot', '')):  # No hotspot condition
                problematic_rule = rule
                print(f"   [FOUND] Rule ID: {rule.get('.id', 'N/A')}")
                print(f"           Chain: {chain}, Action: {action}")
                print(f"           In-Interface-List: {in_interface_list}")
                print(f"           Out-Interface-List: {out_interface_list}")
                print(f"           [ISSUE] No hotspot authentication check!")
                break
        
        # Check for blocking rule
        print("\n2. Checking for Hotspot Blocking Rule...")
        blocking_rule = None
        for rule in filter_rules:
            chain = rule.get('chain', '')
            in_interface = rule.get('in-interface', '')
            in_interface_list = rule.get('in-interface-list', '')
            action = rule.get('action', '')
            hotspot = rule.get('hotspot', '')
            
            # Look for rule blocking unauthenticated hotspot traffic
            if (chain == 'forward' and
                action == 'drop' and
                hotspot == '!auth' and
                (in_interface == 'bridge-hotspot' or in_interface_list == 'LAN')):
                blocking_rule = rule
                print(f"   [FOUND] Blocking rule ID: {rule.get('.id', 'N/A')}")
                break
        
        if not blocking_rule:
            print("   [MISSING] No rule to block unauthenticated hotspot traffic")
        
        # Check for allow authenticated rule
        print("\n3. Checking for Authenticated Traffic Allow Rule...")
        auth_rule = None
        for rule in filter_rules:
            chain = rule.get('chain', '')
            in_interface = rule.get('in-interface', '')
            in_interface_list = rule.get('in-interface-list', '')
            action = rule.get('action', '')
            hotspot = rule.get('hotspot', '')
            connection_state = rule.get('connection-state', '')
            
            if (chain == 'forward' and
                action == 'accept' and
                hotspot == 'auth' and
                (in_interface == 'bridge-hotspot' or in_interface_list == 'LAN')):
                auth_rule = rule
                print(f"   [FOUND] Allow authenticated rule ID: {rule.get('.id', 'N/A')}")
                break
        
        if not auth_rule:
            print("   [MISSING] No rule to allow authenticated hotspot traffic")
        
        # Fix the issue
        print("\n" + "=" * 70)
        print("APPLYING FIXES")
        print("=" * 70)
        
        fixes_applied = []
        
        # Step 1: Modify the problematic rule to exclude unauthenticated hotspot traffic
        if problematic_rule:
            print("\n1. Modifying LAN->WAN rule to exclude unauthenticated hotspot...")
            try:
                # Add hotspot condition to exclude unauthenticated users
                # We'll disable the old rule and create a new one with hotspot condition
                rule_id = problematic_rule.get('.id')
                
                # Get the rule details
                in_list = problematic_rule.get('in-interface-list', '')
                out_list = problematic_rule.get('out-interface-list', '')
                connection_state = problematic_rule.get('connection-state', '')
                comment = problematic_rule.get('comment', '')
                
                # Disable the old rule
                resource.set(id=rule_id, disabled='yes')
                fixes_applied.append(f"Disabled rule {rule_id} that allowed unauthenticated LAN->WAN")
                print(f"   [OK] Disabled problematic rule {rule_id}")
                
                # Create new rule that allows LAN->WAN but excludes unauthenticated hotspot
                # Allow admin network (10.1.1.0/24) to WAN
                resource.add(
                    chain='forward',
                    action='accept',
                    in-interface-list='LAN',
                    out-interface-list='WAN',
                    src-address='10.1.1.0/24',
                    comment='allow-admin-network-to-wan',
                    place-before=0
                )
                fixes_applied.append("Added rule to allow admin network to WAN")
                print("   [OK] Added rule for admin network (10.1.1.0/24) to WAN")
                
                # Allow authenticated hotspot users to WAN
                resource.add(
                    chain='forward',
                    action='accept',
                    in-interface='bridge-hotspot',
                    out-interface-list='WAN',
                    hotspot='auth',
                    comment='allow-authenticated-hotspot-to-wan',
                    place-before=0
                )
                fixes_applied.append("Added rule to allow authenticated hotspot users to WAN")
                print("   [OK] Added rule for authenticated hotspot users to WAN")
                
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Step 2: Add blocking rule if missing
        if not blocking_rule:
            print("\n2. Adding rule to block unauthenticated hotspot traffic...")
            try:
                resource.add(
                    chain='forward',
                    action='drop',
                    in-interface='bridge-hotspot',
                    hotspot='!auth',
                    comment='block-unauthenticated-hotspot',
                    place-before=0
                )
                fixes_applied.append("Added rule to block unauthenticated hotspot traffic")
                print("   [OK] Blocking rule added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Step 3: Add allow authenticated rule if missing
        if not auth_rule:
            print("\n3. Adding rule to allow authenticated established connections...")
            try:
                resource.add(
                    chain='forward',
                    action='accept',
                    in-interface='bridge-hotspot',
                    connection_state='established,related',
                    hotspot='auth',
                    comment='allow-authenticated-established',
                    place-before=0
                )
                fixes_applied.append("Added rule to allow authenticated established connections")
                print("   [OK] Allow authenticated rule added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Step 4: Verify NAT redirect rules
        print("\n4. Verifying NAT Redirect Rules...")
        nat_resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = nat_resource.get()
        
        http_redirect = [r for r in nat_rules if 
                        r.get('chain', '') == 'dstnat' and
                        r.get('action', '') == 'redirect' and
                        r.get('in-interface', '') == 'wifi2-hotspot' and
                        r.get('dst-port', '') == '80' and
                        r.get('disabled', 'no') == 'no']
        
        https_redirect = [r for r in nat_rules if 
                         r.get('chain', '') == 'dstnat' and
                         r.get('action', '') == 'redirect' and
                         r.get('in-interface', '') == 'wifi2-hotspot' and
                         r.get('dst-port', '') == '443' and
                         r.get('disabled', 'no') == 'no']
        
        print(f"   HTTP Redirect: {'OK' if http_redirect else 'MISSING'}")
        print(f"   HTTPS Redirect: {'OK' if https_redirect else 'MISSING'}")
        
        if not http_redirect:
            try:
                nat_resource.add(
                    chain='dstnat',
                    action='redirect',
                    in_interface='wifi2-hotspot',
                    protocol='tcp',
                    dst_port='80',
                    to_ports='80',
                    comment='hotspot-http-redirect'
                )
                fixes_applied.append("Added HTTP redirect rule")
                print("   [OK] HTTP redirect rule added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        if not https_redirect:
            try:
                nat_resource.add(
                    chain='dstnat',
                    action='redirect',
                    in_interface='wifi2-hotspot',
                    protocol='tcp',
                    dst_port='443',
                    to_ports='80',
                    comment='hotspot-https-redirect'
                )
                fixes_applied.append("Added HTTPS redirect rule")
                print("   [OK] HTTPS redirect rule added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Summary
        print("\n" + "=" * 70)
        print("FIXES APPLIED")
        print("=" * 70)
        
        if fixes_applied:
            print(f"\n[FIXES: {len(fixes_applied)}]")
            for fix in fixes_applied:
                print(f"  - {fix}")
        else:
            print("\n[OK] No fixes needed")
        
        print("\n" + "=" * 70)
        print("CONFIGURATION FIXED")
        print("=" * 70)
        print("\nThe hotspot 'Bawal Balik' should now:")
        print("  1. Block all unauthenticated traffic")
        print("  2. Force users to login before accessing internet")
        print("  3. Redirect users to login page automatically")
        print("  4. Allow authenticated users to browse normally")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    analyze_and_fix()

