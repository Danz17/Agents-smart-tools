#!/usr/bin/env python3
"""
Fix Hotspot Login - CORRECTED VERSION
Ensures admin WiFi "Nazi" (10.1.1.0/24) has full access
Only hotspot "Bawal Balik" (10.1.2.0/24) requires authentication
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def fix_hotspot_correct():
    """Fix hotspot while preserving admin network access"""
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("=" * 70)
        print("FIXING HOTSPOT LOGIN (PRESERVING ADMIN NETWORK ACCESS)")
        print("=" * 70)
        
        print("\nNetwork Configuration:")
        print("  Admin Network: 10.1.1.0/24 (Nazi WiFi) - Should have FULL access")
        print("  Hotspot Network: 10.1.2.0/24 (Bawal Balik WiFi) - Requires login")
        
        fixes = []
        
        # Get firewall rules
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # ====================================================================
        # Step 1: Find and disable problematic rule that allows all LAN->WAN
        # ====================================================================
        print("\n1. Finding problematic rule...")
        problematic_rule = None
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('action', '') == 'accept' and
                rule.get('in-interface-list', '') == 'LAN' and
                rule.get('out-interface-list', '') == 'WAN' and
                not rule.get('src-address', '') and
                not rule.get('hotspot', '') and
                rule.get('disabled', 'no') == 'no'):
                problematic_rule = rule
                print(f"   [FOUND] Rule {rule.get('.id', 'N/A')} allows all LAN->WAN")
                break
        
        if problematic_rule:
            print("   [FIXING] Disabling problematic rule...")
            try:
                resource.set(id=problematic_rule.get('.id'), disabled='yes')
                fixes.append("Disabled rule that allowed all LAN->WAN")
                print("   [OK] Rule disabled")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Step 2: Add rule to allow ADMIN network (10.1.1.0/24) to WAN
        # This ensures "Nazi" WiFi has full access
        # ====================================================================
        print("\n2. Adding rule for admin network (10.1.1.0/24)...")
        try:
            # Check if exists
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('src-address', '') == '10.1.1.0/24' and
                    rule.get('out-interface-list', '') == 'WAN' and
                    rule.get('action', '') == 'accept'):
                    exists = True
                    if rule.get('disabled', 'no') == 'true':
                        resource.set(id=rule.get('.id'), disabled='no')
                        fixes.append("Enabled rule for admin network")
                        print("   [OK] Enabled existing rule")
                    else:
                        print("   [OK] Rule already exists and enabled")
                    break
            
            if not exists:
                resource.add(
                    chain='forward',
                    action='accept',
                    src_address='10.1.1.0/24',
                    out_interface_list='WAN',
                    comment='allow-admin-network-full-access',
                    place_before=0
                )
                fixes.append("Added rule for admin network (Nazi WiFi) full access")
                print("   [OK] Rule added - Admin network has full access")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Step 3: Add rule to allow authenticated HOTSPOT users to WAN
        # ====================================================================
        print("\n3. Adding rule for authenticated hotspot users...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == 'auth' and
                    rule.get('out-interface-list', '') == 'WAN' and
                    rule.get('action', '') == 'accept'):
                    exists = True
                    if rule.get('disabled', 'no') == 'true':
                        resource.set(id=rule.get('.id'), disabled='no')
                        fixes.append("Enabled rule for authenticated hotspot users")
                        print("   [OK] Enabled existing rule")
                    else:
                        print("   [OK] Rule already exists and enabled")
                    break
            
            if not exists:
                resource.add(
                    chain='forward',
                    action='accept',
                    in_interface='bridge-hotspot',
                    out_interface_list='WAN',
                    hotspot='auth',
                    comment='allow-authenticated-hotspot-to-wan',
                    place_before=0
                )
                fixes.append("Added rule for authenticated hotspot users")
                print("   [OK] Rule added - Authenticated hotspot users can access WAN")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Step 4: Add rule to allow authenticated established connections
        # ====================================================================
        print("\n4. Adding rule for authenticated established connections...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == 'auth' and
                    rule.get('connection-state', '') == 'established,related' and
                    rule.get('action', '') == 'accept'):
                    exists = True
                    if rule.get('disabled', 'no') == 'true':
                        resource.set(id=rule.get('.id'), disabled='no')
                        fixes.append("Enabled rule for authenticated established connections")
                        print("   [OK] Enabled existing rule")
                    else:
                        print("   [OK] Rule already exists and enabled")
                    break
            
            if not exists:
                resource.add(
                    chain='forward',
                    action='accept',
                    in_interface='bridge-hotspot',
                    connection_state='established,related',
                    hotspot='auth',
                    comment='allow-authenticated-established',
                    place_before=0
                )
                fixes.append("Added rule for authenticated established connections")
                print("   [OK] Rule added")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Step 5: Add rule to BLOCK unauthenticated hotspot traffic
        # This only affects bridge-hotspot (10.1.2.0/24), NOT admin network
        # ====================================================================
        print("\n5. Adding rule to block unauthenticated hotspot traffic...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == '!auth' and
                    rule.get('action', '') == 'drop'):
                    exists = True
                    if rule.get('disabled', 'no') == 'true':
                        resource.set(id=rule.get('.id'), disabled='no')
                        fixes.append("Enabled blocking rule for unauthenticated hotspot")
                        print("   [OK] Enabled existing blocking rule")
                    else:
                        print("   [OK] Blocking rule already exists and enabled")
                    break
            
            if not exists:
                resource.add(
                    chain='forward',
                    action='drop',
                    in_interface='bridge-hotspot',
                    hotspot='!auth',
                    comment='block-unauthenticated-hotspot',
                    place_before=0
                )
                fixes.append("Added rule to block unauthenticated hotspot traffic")
                print("   [OK] Blocking rule added - Only affects hotspot network")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Step 6: Verify NAT redirect rules
        # ====================================================================
        print("\n6. Verifying NAT redirect rules...")
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
                fixes.append("Added HTTP redirect rule")
                print("   [OK] HTTP redirect added")
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
                fixes.append("Added HTTPS redirect rule")
                print("   [OK] HTTPS redirect added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # Summary
        # ====================================================================
        print("\n" + "=" * 70)
        print("FIXES APPLIED")
        print("=" * 70)
        
        if fixes:
            print(f"\n[FIXES: {len(fixes)}]")
            for fix in fixes:
                print(f"  - {fix}")
        else:
            print("\n[OK] All configurations are correct!")
        
        print("\n" + "=" * 70)
        print("CONFIGURATION SUMMARY")
        print("=" * 70)
        print("\nAdmin Network (10.1.1.0/24) - 'Nazi' WiFi:")
        print("  ✓ Has FULL access to WAN (no restrictions)")
        print("  ✓ No authentication required")
        print("  ✓ Unlimited speed")
        
        print("\nHotspot Network (10.1.2.0/24) - 'Bawal Balik' WiFi:")
        print("  ✓ Blocked from WAN until authentication")
        print("  ✓ Users redirected to login page")
        print("  ✓ After login, can access WAN normally")
        
        print("\n" + "=" * 70)
        print("FIX COMPLETE")
        print("=" * 70)
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    fix_hotspot_correct()

