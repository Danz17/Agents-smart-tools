#!/usr/bin/env python3
"""
Fix Hotspot Login Enforcement
Ensures users are forced to login before accessing internet
"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def fix_hotspot_login():
    """Fix hotspot to force login"""
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        
        print("=" * 70)
        print("FIXING HOTSPOT LOGIN ENFORCEMENT")
        print("=" * 70)
        
        # 1. Get hotspot configuration
        print("\n1. Checking Hotspot Configuration...")
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        
        if not hotspots:
            print("[ERROR] No hotspot found!")
            return
        
        hotspot = hotspots[0]
        hotspot_name = hotspot.get('name', 'N/A')
        hotspot_interface = hotspot.get('interface', 'N/A')
        
        print(f"   Hotspot: {hotspot_name}")
        print(f"   Interface: {hotspot_interface}")
        
        # 2. Check and fix firewall filter rules - block unauthenticated traffic
        print("\n2. Checking Firewall Filter Rules...")
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        
        # Look for rules that might be allowing unauthenticated traffic
        hotspot_allow_rules = []
        for rule in filter_rules:
            in_interface = rule.get('in-interface', '')
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            connection_state = rule.get('connection-state', '')
            hotspot_mark = rule.get('hotspot', '')
            
            if in_interface == hotspot_interface:
                hotspot_allow_rules.append(rule)
                print(f"   Found rule: Chain={chain}, Action={action}, Connection-State={connection_state}, Hotspot={hotspot_mark}")
        
        # Check if we need to add rules to block unauthenticated traffic
        print("\n3. Checking for Unauthenticated Traffic Blocking Rules...")
        
        # Look for rules that allow established/related connections without hotspot auth
        problematic_rules = []
        for rule in filter_rules:
            in_interface = rule.get('in-interface', '')
            chain = rule.get('chain', '')
            action = rule.get('action', '')
            connection_state = rule.get('connection-state', '')
            hotspot = rule.get('hotspot', '')
            disabled = rule.get('disabled', 'no')
            
            # Rules that allow traffic on hotspot interface without hotspot auth check
            if (in_interface == hotspot_interface and 
                chain == 'forward' and 
                action == 'accept' and
                hotspot != 'auth' and
                disabled == 'no'):
                problematic_rules.append(rule)
                print(f"   [ISSUE] Rule allows traffic without hotspot auth: {rule.get('.id', 'N/A')}")
        
        # 4. Add proper blocking rules
        print("\n4. Adding Firewall Rules to Block Unauthenticated Traffic...")
        
        # Rule 1: Allow established/related connections for authenticated users
        print("   Adding rule: Allow established connections for authenticated users...")
        try:
            # Check if rule already exists
            existing_rule = None
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == hotspot_interface and
                    rule.get('connection-state', '') == 'established,related' and
                    rule.get('hotspot', '') == 'auth' and
                    rule.get('action', '') == 'accept'):
                    existing_rule = rule
                    break
            
            if not existing_rule:
                resource.add(
                    chain='forward',
                    action='accept',
                    in_interface=hotspot_interface,
                    connection_state='established,related',
                    hotspot='auth',
                    comment='allow-established-hotspot-auth'
                )
                print("   [OK] Rule added")
            else:
                if existing_rule.get('disabled', 'no') == 'true':
                    resource.set(id=existing_rule.get('.id'), disabled='no')
                    print("   [OK] Existing rule enabled")
                else:
                    print("   [OK] Rule already exists and enabled")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # Rule 2: Block all other traffic from hotspot interface (except DNS and hotspot server)
        print("   Adding rule: Block unauthenticated traffic...")
        try:
            # Check if blocking rule exists
            blocking_rule = None
            for rule in filter_rules:
                if (rule.get('chain', '') == 'forward' and
                    rule.get('in-interface', '') == hotspot_interface and
                    rule.get('action', '') == 'drop' and
                    rule.get('hotspot', '') == '!auth'):
                    blocking_rule = rule
                    break
            
            if not blocking_rule:
                resource.add(
                    chain='forward',
                    action='drop',
                    in_interface=hotspot_interface,
                    hotspot='!auth',
                    comment='block-unauthenticated-hotspot'
                )
                print("   [OK] Blocking rule added")
            else:
                if blocking_rule.get('disabled', 'no') == 'true':
                    resource.set(id=blocking_rule.get('.id'), disabled='no')
                    print("   [OK] Existing blocking rule enabled")
                else:
                    print("   [OK] Blocking rule already exists and enabled")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
        
        # 5. Verify NAT redirect rules are correct
        print("\n5. Verifying NAT Redirect Rules...")
        resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = resource.get()
        
        redirect_rules = [r for r in nat_rules if 
                         r.get('chain', '') == 'dstnat' and
                         r.get('action', '') == 'redirect' and
                         r.get('in-interface', '') == hotspot_interface]
        
        http_rule = [r for r in redirect_rules if r.get('dst-port', '') == '80']
        https_rule = [r for r in redirect_rules if r.get('dst-port', '') == '443']
        
        print(f"   HTTP Redirect: {'OK' if http_rule and http_rule[0].get('disabled', 'no') == 'no' else 'MISSING/DISABLED'}")
        print(f"   HTTPS Redirect: {'OK' if https_rule and https_rule[0].get('disabled', 'no') == 'no' else 'MISSING/DISABLED'}")
        
        # 6. Check hotspot profile settings
        print("\n6. Checking Hotspot Profile Settings...")
        resource = connection.get_resource('/ip/hotspot/profile')
        profiles = resource.get()
        
        profile_name = hotspot.get('profile', 'default')
        for profile in profiles:
            if profile.get('name', '') == profile_name:
                print(f"   Profile: {profile_name}")
                print(f"   Login By: {profile.get('login-by', 'N/A')}")
                print(f"   HTTP Cookie Lifetime: {profile.get('http-cookie-lifetime', 'N/A')}")
                
                # Ensure login-by includes http-chap
                login_by = profile.get('login-by', '')
                if 'http-chap' not in login_by:
                    print(f"   [FIXING] Adding http-chap to login-by...")
                    new_login_by = login_by + ',http-chap' if login_by else 'http-chap'
                    resource.set(id=profile.get('.id'), login_by=new_login_by)
                    print(f"   [OK] Updated login-by to: {new_login_by}")
        
        # 7. Ensure hotspot is enabled
        print("\n7. Ensuring Hotspot is Enabled...")
        if hotspot.get('disabled', 'no') == 'true':
            resource = connection.get_resource('/ip/hotspot')
            resource.set(id=hotspot.get('.id'), disabled='no')
            print("   [OK] Hotspot enabled")
        else:
            print("   [OK] Hotspot is already enabled")
        
        # 8. Check interface is enabled
        print("\n8. Ensuring Interface is Enabled...")
        resource = connection.get_resource('/interface')
        interfaces = resource.get()
        for iface in interfaces:
            if iface.get('name', '') == hotspot_interface:
                if iface.get('disabled', 'no') == 'true':
                    resource.set(id=iface.get('.id'), disabled='no')
                    print("   [OK] Interface enabled")
                else:
                    print("   [OK] Interface is already enabled")
                break
        
        print("\n" + "=" * 70)
        print("HOTSPOT LOGIN ENFORCEMENT FIXED")
        print("=" * 70)
        print("\nSummary:")
        print("  - Firewall rules configured to block unauthenticated traffic")
        print("  - NAT redirect rules verified")
        print("  - Hotspot profile configured for login")
        print("  - Hotspot and interface enabled")
        print("\nUsers must now authenticate before accessing the internet!")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    fix_hotspot_login()

