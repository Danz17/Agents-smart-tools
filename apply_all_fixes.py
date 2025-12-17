#!/usr/bin/env python3
"""
Apply All Fixes Based on Export Analysis
Fixes hotspot login enforcement and applies all improvements
"""

from routeros_api import connect
import time

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def apply_fixes():
    """Apply all fixes"""
    try:
        print("Connecting to router...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        print("[OK] Connected\n")
        
        print("=" * 70)
        print("APPLYING ALL FIXES")
        print("=" * 70)
        
        fixes = []
        
        # ====================================================================
        # FIX 1: Hotspot Login Enforcement
        # ====================================================================
        print("\n[FIX 1] Hotspot Login Enforcement")
        print("-" * 70)
        
        # Get firewall rules
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # Find problematic rule
        problematic_rule = None
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('action', '') == 'accept' and
                rule.get('in-interface-list', '') == 'LAN' and
                rule.get('out-interface-list', '') == 'WAN' and
                not rule.get('hotspot', '') and
                not rule.get('src-address', '') and
                rule.get('disabled', 'no') == 'no'):
                problematic_rule = rule
                break
        
        if problematic_rule:
            print("   [FOUND] Problematic rule allowing all LAN->WAN")
            print(f"   [FIXING] Disabling rule {problematic_rule.get('.id', 'N/A')}...")
            try:
                resource.set(id=problematic_rule.get('.id'), disabled='yes')
                fixes.append("Disabled rule that allowed unauthenticated LAN->WAN")
                print("   [OK] Rule disabled")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        
        # Add rule for admin network
        print("   [ADDING] Rule for admin network (10.1.1.0/24)...")
        try:
            # Check if exists
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('src-address', '') == '10.1.1.0/24' and
                    rule.get('in-interface-list', '') == 'LAN' and
                    rule.get('out-interface-list', '') == 'WAN'):
                    exists = True
                    break
            
            if not exists:
                resource.add(
                    chain='forward',
                    action='accept',
                    in_interface_list='LAN',
                    out_interface_list='WAN',
                    src_address='10.1.1.0/24',
                    comment='allow-admin-network-to-wan',
                    place_before=0
                )
                fixes.append("Added rule for admin network to WAN")
                print("   [OK] Rule added")
            else:
                print("   [OK] Rule already exists")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # Add rule for authenticated hotspot users
        print("   [ADDING] Rule for authenticated hotspot users...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == 'auth' and
                    rule.get('out-interface-list', '') == 'WAN'):
                    exists = True
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
                fixes.append("Added rule for authenticated hotspot users to WAN")
                print("   [OK] Rule added")
            else:
                print("   [OK] Rule already exists")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # Add rule for authenticated established connections
        print("   [ADDING] Rule for authenticated established connections...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == 'auth' and
                    rule.get('connection-state', '') == 'established,related'):
                    exists = True
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
            else:
                print("   [OK] Rule already exists")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # Add blocking rule
        print("   [ADDING] Rule to block unauthenticated hotspot traffic...")
        try:
            exists = False
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == 'bridge-hotspot' and
                    rule.get('hotspot', '') == '!auth' and
                    rule.get('action', '') == 'drop'):
                    exists = True
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
                print("   [OK] Blocking rule added")
            else:
                print("   [OK] Blocking rule already exists")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # ====================================================================
        # FIX 2: Verify NAT Redirect Rules
        # ====================================================================
        print("\n[FIX 2] Verifying NAT Redirect Rules")
        print("-" * 70)
        
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
        # FIX 3: Configure DNS
        # ====================================================================
        print("\n[FIX 3] Configuring DNS")
        print("-" * 70)
        
        dns_resource = connection.get_resource('/ip/dns')
        dns_config = dns_resource.get()
        
        if dns_config:
            dns = dns_config[0]
            current_servers = dns.get('servers', '')
            print(f"   Current DNS: {current_servers}")
            
            # Add public DNS if not present
            if '8.8.8.8' not in current_servers:
                new_servers = f"{current_servers},8.8.8.8,1.1.1.1" if current_servers else "8.8.8.8,1.1.1.1"
                try:
                    dns_resource.set(id=dns.get('.id'), servers=new_servers)
                    fixes.append(f"Added public DNS servers: {new_servers}")
                    print(f"   [OK] DNS updated: {new_servers}")
                except Exception as e:
                    print(f"   [ERROR] {str(e)}")
            else:
                print("   [OK] Public DNS already configured")
        
        # ====================================================================
        # SUMMARY
        # ====================================================================
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)
        
        if fixes:
            print(f"\n[FIXES APPLIED: {len(fixes)}]")
            for fix in fixes:
                print(f"  - {fix}")
        else:
            print("\n[OK] All configurations are correct!")
        
        print("\n" + "=" * 70)
        print("ALL FIXES COMPLETED")
        print("=" * 70)
        print("\nThe hotspot 'Bawal Balik' should now:")
        print("  ✓ Block unauthenticated traffic")
        print("  ✓ Force users to login before accessing internet")
        print("  ✓ Redirect users to login page automatically")
        print("  ✓ Allow authenticated users to browse normally")
        print("\nTest by connecting to 'Bawal Balik' WiFi and opening a browser.")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    apply_fixes()

