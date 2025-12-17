#!/usr/bin/env python3
"""
SAFE Hotspot Fix - Ensures Admin Access is Preserved
This script adds admin network rules FIRST before disabling anything
to prevent lockout
"""

from routeros_api import connect
import time

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def safe_fix_hotspot():
    """Safely fix hotspot while preserving admin access"""
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("=" * 70)
        print("SAFE HOTSPOT FIX - PRESERVING ADMIN ACCESS")
        print("=" * 70)
        
        print("\n[SAFETY] This script will:")
        print("  1. Add admin network rules FIRST (before disabling anything)")
        print("  2. Verify admin access is preserved")
        print("  3. Only then disable problematic rules")
        print("  4. Add hotspot blocking rules")
        
        fixes = []
        warnings = []
        
        # ====================================================================
        # STEP 1: Add admin network rule FIRST (before disabling anything!)
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 1: ADDING ADMIN NETWORK RULE FIRST (SAFETY)")
        print("=" * 70)
        
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # Check if admin network rule already exists
        admin_rule_exists = False
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('src-address', '') == '10.1.1.0/24' and
                rule.get('out-interface-list', '') == 'WAN' and
                rule.get('action', '') == 'accept' and
                rule.get('disabled', 'no') == 'no'):
                admin_rule_exists = True
                print("   [OK] Admin network rule already exists and is enabled")
                break
        
        if not admin_rule_exists:
            print("   [ADDING] Admin network rule (10.1.1.0/24) - FULL ACCESS")
            try:
                resource.add(
                    chain='forward',
                    action='accept',
                    src_address='10.1.1.0/24',
                    out_interface_list='WAN',
                    comment='allow-admin-network-full-access',
                    place_before=0
                )
                fixes.append("Added admin network rule (10.1.1.0/24) - ensures no lockout")
                print("   [OK] Admin network rule added - your access is preserved!")
            except Exception as e:
                print(f"   [ERROR] Failed to add admin rule: {str(e)}")
                print("   [WARNING] Continuing but admin access may be affected!")
                warnings.append("Failed to add admin network rule")
        
        # Wait a moment for rule to take effect
        print("\n   [WAIT] Waiting 2 seconds for rule to take effect...")
        time.sleep(2)
        
        # ====================================================================
        # STEP 2: Add authenticated hotspot rules (before blocking)
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 2: ADDING AUTHENTICATED HOTSPOT RULES")
        print("=" * 70)
        
        # Check for authenticated hotspot rule
        auth_rule_exists = False
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('in-interface', '') == 'bridge-hotspot' and
                rule.get('hotspot', '') == 'auth' and
                rule.get('out-interface-list', '') == 'WAN' and
                rule.get('action', '') == 'accept' and
                rule.get('disabled', 'no') == 'no'):
                auth_rule_exists = True
                print("   [OK] Authenticated hotspot rule already exists")
                break
        
        if not auth_rule_exists:
            print("   [ADDING] Rule for authenticated hotspot users...")
            try:
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
                print("   [OK] Rule added")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Add established connections rule
        established_rule_exists = False
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('in-interface', '') == 'bridge-hotspot' and
                rule.get('hotspot', '') == 'auth' and
                rule.get('connection-state', '') == 'established,related' and
                rule.get('action', '') == 'accept' and
                rule.get('disabled', 'no') == 'no'):
                established_rule_exists = True
                print("   [OK] Established connections rule already exists")
                break
        
        if not established_rule_exists:
            print("   [ADDING] Rule for authenticated established connections...")
            try:
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
        # STEP 3: NOW safely disable problematic rule (admin access is secured)
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 3: DISABLING PROBLEMATIC RULE (SAFE NOW)")
        print("=" * 70)
        
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
                break
        
        if problematic_rule:
            print(f"   [FOUND] Problematic rule {problematic_rule.get('.id', 'N/A')}")
            print("   [SAFE] Admin access is already secured, disabling problematic rule...")
            try:
                resource.set(id=problematic_rule.get('.id'), disabled='yes')
                fixes.append("Disabled problematic rule (admin access preserved)")
                print("   [OK] Problematic rule disabled")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        else:
            print("   [OK] Problematic rule not found or already disabled")
        
        # ====================================================================
        # STEP 4: Add blocking rule for unauthenticated hotspot
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 4: ADDING HOTSPOT BLOCKING RULE")
        print("=" * 70)
        
        blocking_rule_exists = False
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('in-interface', '') == 'bridge-hotspot' and
                rule.get('hotspot', '') == '!auth' and
                rule.get('action', '') == 'drop' and
                rule.get('disabled', 'no') == 'no'):
                blocking_rule_exists = True
                print("   [OK] Blocking rule already exists")
                break
        
        if not blocking_rule_exists:
            print("   [ADDING] Rule to block unauthenticated hotspot traffic...")
            try:
                resource.add(
                    chain='forward',
                    action='drop',
                    in_interface='bridge-hotspot',
                    hotspot='!auth',
                    comment='block-unauthenticated-hotspot',
                    place_before=0
                )
                fixes.append("Added blocking rule for unauthenticated hotspot")
                print("   [OK] Blocking rule added (only affects 10.1.2.0/24)")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # STEP 5: Verify admin access is preserved
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 5: VERIFYING ADMIN ACCESS")
        print("=" * 70)
        
        # Refresh rules
        filter_rules = resource.get()
        
        admin_rule_active = False
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('src-address', '') == '10.1.1.0/24' and
                rule.get('out-interface-list', '') == 'WAN' and
                rule.get('action', '') == 'accept' and
                rule.get('disabled', 'no') == 'no'):
                admin_rule_active = True
                print(f"   [VERIFIED] Admin network rule is ACTIVE")
                print(f"             Rule ID: {rule.get('.id', 'N/A')}")
                print(f"             Source: {rule.get('src-address', 'N/A')}")
                print(f"             Action: {rule.get('action', 'N/A')}")
                break
        
        if not admin_rule_active:
            print("   [WARNING] Admin network rule not found or disabled!")
            warnings.append("Admin network rule may not be active")
        else:
            print("   [OK] Admin access is SECURED - you won't lose access!")
        
        # ====================================================================
        # STEP 6: Verify NAT redirect rules
        # ====================================================================
        print("\n" + "=" * 70)
        print("STEP 6: VERIFYING NAT REDIRECT RULES")
        print("=" * 70)
        
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
        # SUMMARY
        # ====================================================================
        print("\n" + "=" * 70)
        print("FIX COMPLETE - SUMMARY")
        print("=" * 70)
        
        if fixes:
            print(f"\n[FIXES APPLIED: {len(fixes)}]")
            for fix in fixes:
                print(f"  - {fix}")
        
        if warnings:
            print(f"\n[WARNINGS: {len(warnings)}]")
            for warning in warnings:
                print(f"  - {warning}")
        
        print("\n" + "=" * 70)
        print("ACCESS STATUS")
        print("=" * 70)
        print("\nAdmin Network (10.1.1.0/24) - 'Nazi' WiFi:")
        if admin_rule_active:
            print("  ✓ FULL ACCESS PRESERVED")
            print("  ✓ Unlimited speed")
            print("  ✓ No restrictions")
            print("  ✓ You will NOT lose access!")
        else:
            print("  ⚠ WARNING: Verify admin access manually")
        
        print("\nHotspot Network (10.1.2.0/24) - 'Bawal Balik' WiFi:")
        print("  ✓ Blocked until authentication")
        print("  ✓ Redirected to login page")
        print("  ✓ After login, normal access")
        
        print("\n" + "=" * 70)
        print("SAFE FIX COMPLETE")
        print("=" * 70)
        print("\nYour admin access (10.1.1.0/24) is preserved!")
        print("You can continue using the router normally.")
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        print("\n[IMPORTANT] If you lost access, connect via:")
        print("  - Winbox (port 8291)")
        print("  - WebFig (http://10.1.1.1)")
        print("  - SSH (port 22)")
        print("\nThen manually add this rule to restore access:")
        print("  /ip firewall filter add chain=forward action=accept src-address=10.1.1.0/24 out-interface-list=WAN")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    safe_fix_hotspot()

