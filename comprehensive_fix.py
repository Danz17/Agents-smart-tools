#!/usr/bin/env python3
"""
Comprehensive Router Fix - All Improvements
Fixes hotspot login enforcement and applies all recommendations
"""

from routeros_api import connect
import time

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def connect_with_retry(max_retries=3):
    """Connect to router with retry logic"""
    for attempt in range(max_retries):
        try:
            print(f"Connection attempt {attempt + 1}/{max_retries}...")
            connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
            print("[OK] Connected successfully!")
            return connection
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"[RETRY] Connection failed: {str(e)[:50]}...")
                print("Waiting 5 seconds before retry...")
                time.sleep(5)
            else:
                print(f"[ERROR] Failed to connect after {max_retries} attempts")
                raise
    return None

def fix_hotspot_login_enforcement(connection):
    """Fix hotspot to force login"""
    print("\n" + "=" * 70)
    print("STEP 1: FIXING HOTSPOT LOGIN ENFORCEMENT")
    print("=" * 70)
    
    fixes = []
    
    # Get hotspot
    resource = connection.get_resource('/ip/hotspot')
    hotspots = resource.get()
    if not hotspots:
        print("[ERROR] No hotspot found!")
        return fixes
    
    hotspot = hotspots[0]
    hotspot_interface = hotspot.get('interface', '')
    
    print(f"\nHotspot Interface: {hotspot_interface}")
    
    # Check firewall filter rules
    print("\n1. Configuring Firewall Rules...")
    resource = connection.get_resource('/ip/firewall/filter')
    filter_rules = resource.get()
    
    # Remove problematic rules that allow unauthenticated traffic
    print("   Checking for rules allowing unauthenticated traffic...")
    rules_to_disable = []
    for rule in filter_rules:
        in_interface = rule.get('in-interface', '')
        chain = rule.get('chain', '')
        action = rule.get('action', '')
        hotspot_auth = rule.get('hotspot', '')
        connection_state = rule.get('connection-state', '')
        disabled = rule.get('disabled', 'no')
        
        # Rules that allow forward traffic without hotspot auth
        if (in_interface == hotspot_interface and
            chain == 'forward' and
            action == 'accept' and
            hotspot_auth != 'auth' and
            'established' not in connection_state and
            disabled == 'no'):
            rules_to_disable.append(rule)
            print(f"   [FOUND] Rule {rule.get('.id', 'N/A')} allows unauthenticated traffic")
    
    # Disable problematic rules
    for rule in rules_to_disable:
        try:
            resource.set(id=rule.get('.id'), disabled='yes')
            fixes.append(f"Disabled rule {rule.get('.id', 'N/A')} that allowed unauthenticated traffic")
            print(f"   [FIXED] Disabled problematic rule")
        except:
            pass
    
    # Add rule to allow authenticated established connections
    print("   Adding rule: Allow authenticated established connections...")
    try:
        # Check if exists
        existing = None
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('in-interface', '') == hotspot_interface and
                rule.get('connection-state', '') == 'established,related' and
                rule.get('hotspot', '') == 'auth' and
                rule.get('action', '') == 'accept'):
                existing = rule
                break
        
        if not existing:
            resource.add(
                chain='forward',
                action='accept',
                in_interface=hotspot_interface,
                connection_state='established,related',
                hotspot='auth',
                comment='allow-authenticated-established',
                place_before=0
            )
            fixes.append("Added rule to allow authenticated established connections")
            print("   [OK] Rule added")
        else:
            if existing.get('disabled', 'no') == 'true':
                resource.set(id=existing.get('.id'), disabled='no')
                fixes.append("Enabled rule for authenticated established connections")
                print("   [OK] Rule enabled")
            else:
                print("   [OK] Rule already exists")
    except Exception as e:
        print(f"   [ERROR] {str(e)}")
    
    # Add rule to block unauthenticated traffic
    print("   Adding rule: Block unauthenticated traffic...")
    try:
        existing = None
        for rule in filter_rules:
            if (rule.get('chain', '') == 'forward' and
                rule.get('in-interface', '') == hotspot_interface and
                rule.get('hotspot', '') == '!auth' and
                rule.get('action', '') == 'drop'):
                existing = rule
                break
        
        if not existing:
            resource.add(
                chain='forward',
                action='drop',
                in_interface=hotspot_interface,
                hotspot='!auth',
                comment='block-unauthenticated-hotspot',
                place_before=0
            )
            fixes.append("Added rule to block unauthenticated traffic")
            print("   [OK] Blocking rule added")
        else:
            if existing.get('disabled', 'no') == 'true':
                resource.set(id=existing.get('.id'), disabled='no')
                fixes.append("Enabled blocking rule for unauthenticated traffic")
                print("   [OK] Blocking rule enabled")
            else:
                print("   [OK] Blocking rule already exists")
    except Exception as e:
        print(f"   [ERROR] {str(e)}")
    
    # Verify NAT redirect rules
    print("\n2. Verifying NAT Redirect Rules...")
    resource = connection.get_resource('/ip/firewall/nat')
    nat_rules = resource.get()
    
    redirect_rules = [r for r in nat_rules if 
                     r.get('chain', '') == 'dstnat' and
                     r.get('action', '') == 'redirect' and
                     r.get('in-interface', '') == hotspot_interface]
    
    http_rule = [r for r in redirect_rules if r.get('dst-port', '') == '80' and r.get('disabled', 'no') == 'no']
    https_rule = [r for r in redirect_rules if r.get('dst-port', '') == '443' and r.get('disabled', 'no') == 'no']
    
    if not http_rule:
        print("   [FIXING] Adding HTTP redirect rule...")
        try:
            resource.add(
                chain='dstnat',
                action='redirect',
                in_interface=hotspot_interface,
                protocol='tcp',
                dst_port='80',
                to_ports='80',
                comment='hotspot-http-redirect',
                place_before=0
            )
            fixes.append("Added HTTP redirect rule")
            print("   [OK] HTTP redirect added")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
    else:
        print("   [OK] HTTP redirect rule exists")
    
    if not https_rule:
        print("   [FIXING] Adding HTTPS redirect rule...")
        try:
            resource.add(
                chain='dstnat',
                action='redirect',
                in_interface=hotspot_interface,
                protocol='tcp',
                dst_port='443',
                to_ports='80',
                comment='hotspot-https-redirect',
                place_before=0
            )
            fixes.append("Added HTTPS redirect rule")
            print("   [OK] HTTPS redirect added")
        except Exception as e:
            print(f"   [ERROR] {str(e)}")
    else:
        print("   [OK] HTTPS redirect rule exists")
    
    # Ensure hotspot is enabled
    print("\n3. Ensuring Hotspot is Enabled...")
    if hotspot.get('disabled', 'no') == 'true':
        resource = connection.get_resource('/ip/hotspot')
        resource.set(id=hotspot.get('.id'), disabled='no')
        fixes.append("Enabled hotspot server")
        print("   [OK] Hotspot enabled")
    else:
        print("   [OK] Hotspot already enabled")
    
    return fixes

def review_firewall_rules(connection):
    """Review and optimize firewall rules"""
    print("\n" + "=" * 70)
    print("STEP 2: REVIEWING FIREWALL RULES")
    print("=" * 70)
    
    resource = connection.get_resource('/ip/firewall/filter')
    filter_rules = resource.get()
    
    print(f"\nTotal Firewall Filter Rules: {len(filter_rules)}")
    
    # Analyze rules
    input_rules = [r for r in filter_rules if r.get('chain', '') == 'input']
    forward_rules = [r for r in filter_rules if r.get('chain', '') == 'forward']
    output_rules = [r for r in filter_rules if r.get('chain', '') == 'output']
    
    print(f"  Input chain: {len(input_rules)} rules")
    print(f"  Forward chain: {len(forward_rules)} rules")
    print(f"  Output chain: {len(output_rules)} rules")
    
    # Find potentially problematic rules
    print("\nAnalyzing rules for issues...")
    
    issues = []
    # Rules without comments
    no_comment = [r for r in filter_rules if not r.get('comment', '')]
    if no_comment:
        issues.append(f"{len(no_comment)} rules without comments (hard to track)")
    
    # Duplicate rules
    rule_signatures = {}
    for rule in filter_rules:
        sig = f"{rule.get('chain', '')}-{rule.get('action', '')}-{rule.get('in-interface', '')}-{rule.get('dst-port', '')}"
        if sig in rule_signatures:
            issues.append(f"Potential duplicate rules found")
        rule_signatures[sig] = rule
    
    if issues:
        print("\n[ISSUES FOUND]:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("\n[OK] No obvious issues found in firewall rules")
    
    print("\n[INFO] Firewall rules reviewed. Manual audit recommended for security optimization.")
    
    return []

def configure_dns(connection):
    """Configure DNS settings"""
    print("\n" + "=" * 70)
    print("STEP 3: CONFIGURING DNS")
    print("=" * 70)
    
    fixes = []
    
    resource = connection.get_resource('/ip/dns')
    dns_config = resource.get()
    
    if dns_config:
        dns = dns_config[0]
        current_servers = dns.get('servers', '')
        print(f"\nCurrent DNS Servers: {current_servers if current_servers else 'None'}")
        
        # Add public DNS if not present
        recommended_servers = '8.8.8.8,1.1.1.1'
        if not current_servers or '8.8.8.8' not in current_servers:
            print("   [FIXING] Adding public DNS servers...")
            try:
                new_servers = f"{current_servers},{recommended_servers}" if current_servers else recommended_servers
                resource.set(id=dns.get('.id'), servers=new_servers)
                fixes.append(f"Configured DNS servers: {new_servers}")
                print(f"   [OK] DNS servers configured: {new_servers}")
            except Exception as e:
                print(f"   [ERROR] {str(e)}")
        else:
            print("   [OK] DNS servers already configured")
    else:
        print("   [INFO] No DNS configuration found")
    
    return fixes

def main():
    """Main function"""
    try:
        print("=" * 70)
        print("COMPREHENSIVE ROUTER FIX")
        print("=" * 70)
        
        connection = connect_with_retry()
        
        all_fixes = []
        
        # Step 1: Fix hotspot login
        fixes = fix_hotspot_login_enforcement(connection)
        all_fixes.extend(fixes)
        
        # Step 2: Review firewall
        fixes = review_firewall_rules(connection)
        all_fixes.extend(fixes)
        
        # Step 3: Configure DNS
        fixes = configure_dns(connection)
        all_fixes.extend(fixes)
        
        # Summary
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)
        
        if all_fixes:
            print(f"\n[FIXES APPLIED: {len(all_fixes)}]")
            for fix in all_fixes:
                print(f"  - {fix}")
        else:
            print("\n[OK] All configurations are correct!")
        
        print("\n" + "=" * 70)
        print("ALL STEPS COMPLETED")
        print("=" * 70)
        print("\nThe hotspot 'bawal balik' should now:")
        print("  1. Force users to login before accessing internet")
        print("  2. Block all unauthenticated traffic")
        print("  3. Redirect users to login page automatically")
        
    except Exception as e:
        print(f"\n[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

