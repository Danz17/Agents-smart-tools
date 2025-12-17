#!/usr/bin/env python3
"""
Verify current router state and apply fixes
"""

from routeros_api import connect
import json

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def verify_and_fix():
    """Verify configuration and apply fixes"""
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("=" * 70)
        print("VERIFYING AND FIXING ROUTER CONFIGURATION")
        print("=" * 70)
        
        fixes_applied = []
        
        # 1. Verify Hotspot
        print("\n1. Checking Hotspot Configuration...")
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        for hotspot in hotspots:
            name = hotspot.get('name', 'N/A')
            disabled = hotspot.get('disabled', 'no')
            interface = hotspot.get('interface', 'N/A')
            
            print(f"   Hotspot: {name}")
            print(f"   Interface: {interface}")
            print(f"   Status: {'Disabled' if disabled == 'true' else 'Enabled'}")
            
            if disabled == 'true':
                print(f"   [FIXING] Enabling hotspot...")
                resource.set(id=hotspot.get('.id'), disabled='no')
                fixes_applied.append(f"Enabled hotspot '{name}'")
                print(f"   [OK] Hotspot enabled")
        
        # 2. Verify Hotspot Interface
        print("\n2. Checking Hotspot Interface...")
        for hotspot in hotspots:
            interface_name = hotspot.get('interface', '')
            if interface_name:
                resource = connection.get_resource('/interface')
                interfaces = resource.get()
                for iface in interfaces:
                    if iface.get('name', '') == interface_name:
                        disabled = iface.get('disabled', 'no')
                        print(f"   Interface: {interface_name}")
                        print(f"   Status: {'Disabled' if disabled == 'true' else 'Enabled'}")
                        if disabled == 'true':
                            print(f"   [FIXING] Enabling interface...")
                            resource.set(id=iface.get('.id'), disabled='no')
                            fixes_applied.append(f"Enabled interface '{interface_name}'")
                            print(f"   [OK] Interface enabled")
                        break
        
        # 3. Verify NAT Redirect Rules
        print("\n3. Checking Hotspot Redirect Rules...")
        for hotspot in hotspots:
            interface_name = hotspot.get('interface', '')
            if interface_name and hotspot.get('disabled', 'no') == 'no':
                resource = connection.get_resource('/ip/firewall/nat')
                nat_rules = resource.get()
                
                redirect_rules = [r for r in nat_rules if 
                                r.get('chain', '') == 'dstnat' and
                                r.get('action', '') == 'redirect' and
                                r.get('in-interface', '') == interface_name]
                
                http_rule = [r for r in redirect_rules if r.get('dst-port', '') == '80']
                https_rule = [r for r in redirect_rules if r.get('dst-port', '') == '443']
                
                print(f"   Interface: {interface_name}")
                print(f"   HTTP Redirect: {'Found' if http_rule else 'Missing'}")
                print(f"   HTTPS Redirect: {'Found' if https_rule else 'Missing'}")
                
                if not http_rule:
                    print(f"   [FIXING] Adding HTTP redirect rule...")
                    resource.add(
                        chain='dstnat',
                        action='redirect',
                        in_interface=interface_name,
                        protocol='tcp',
                        dst_port='80',
                        to_ports='80',
                        comment='hotspot-http-redirect'
                    )
                    fixes_applied.append(f"Added HTTP redirect rule for '{interface_name}'")
                    print(f"   [OK] HTTP redirect rule added")
                
                if not https_rule:
                    print(f"   [FIXING] Adding HTTPS redirect rule...")
                    resource.add(
                        chain='dstnat',
                        action='redirect',
                        in_interface=interface_name,
                        protocol='tcp',
                        dst_port='443',
                        to_ports='80',
                        comment='hotspot-https-redirect'
                    )
                    fixes_applied.append(f"Added HTTPS redirect rule for '{interface_name}'")
                    print(f"   [OK] HTTPS redirect rule added")
                
                # Check for disabled rules
                for rule in redirect_rules:
                    if rule.get('disabled', 'no') == 'true':
                        print(f"   [FIXING] Enabling disabled redirect rule...")
                        resource.set(id=rule.get('.id'), disabled='no')
                        fixes_applied.append(f"Enabled redirect rule")
                        print(f"   [OK] Rule enabled")
        
        # 4. Verify IP Pool
        print("\n4. Checking IP Pools...")
        for hotspot in hotspots:
            pool_name = hotspot.get('address-pool', '')
            if pool_name:
                resource = connection.get_resource('/ip/pool')
                pools = resource.get()
                pool_found = False
                for pool in pools:
                    if pool.get('name', '') == pool_name:
                        pool_found = True
                        ranges = pool.get('ranges', '')
                        print(f"   Pool: {pool_name}")
                        print(f"   Ranges: {ranges if ranges else 'None configured'}")
                        if not ranges:
                            fixes_applied.append(f"WARNING: IP Pool '{pool_name}' has no ranges")
                        break
                if not pool_found:
                    print(f"   [ERROR] IP Pool '{pool_name}' not found!")
                    fixes_applied.append(f"ERROR: IP Pool '{pool_name}' missing")
        
        # Summary
        print("\n" + "=" * 70)
        print("VERIFICATION COMPLETE")
        print("=" * 70)
        
        if fixes_applied:
            print(f"\n[FIXES APPLIED: {len(fixes_applied)}]")
            for fix in fixes_applied:
                print(f"  - {fix}")
        else:
            print("\n[OK] No fixes needed - configuration is correct!")
        
        # Final verification
        print("\n5. Final Status Check...")
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        for hotspot in hotspots:
            name = hotspot.get('name', 'N/A')
            disabled = hotspot.get('disabled', 'no')
            interface = hotspot.get('interface', 'N/A')
            
            print(f"\n   Hotspot '{name}':")
            print(f"     Status: {'ENABLED' if disabled == 'no' else 'DISABLED'}")
            print(f"     Interface: {interface}")
            
            if disabled == 'no':
                # Check redirect rules
                resource = connection.get_resource('/ip/firewall/nat')
                nat_rules = resource.get()
                redirect_rules = [r for r in nat_rules if 
                                r.get('chain', '') == 'dstnat' and
                                r.get('action', '') == 'redirect' and
                                r.get('in-interface', '') == interface and
                                r.get('disabled', 'no') == 'no']
                
                http_rules = [r for r in redirect_rules if r.get('dst-port', '') == '80']
                https_rules = [r for r in redirect_rules if r.get('dst-port', '') == '443']
                
                print(f"     HTTP Redirect: {'OK' if http_rules else 'MISSING'}")
                print(f"     HTTPS Redirect: {'OK' if https_rules else 'MISSING'}")
                
                if http_rules and https_rules:
                    print(f"     [OK] Hotspot is properly configured!")
                else:
                    print(f"     [WARNING] Some redirect rules may be missing")
        
        print("\n" + "=" * 70)
        print("ANALYSIS COMPLETE")
        print("=" * 70)
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    verify_and_fix()


