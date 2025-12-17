#!/usr/bin/env python3
"""
Export and Analyze MikroTik Router Configuration
Exports settings, analyzes for issues, fixes problems, and suggests improvements
"""

from routeros_api import connect
import json
import datetime
import os

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"
PORT = 8728

def export_config(connection):
    """Export router configuration"""
    print("=" * 70)
    print("EXPORTING ROUTER CONFIGURATION")
    print("=" * 70)
    
    config = {
        'export_date': datetime.datetime.now().isoformat(),
        'router_info': {},
        'hotspot': {},
        'interfaces': {},
        'firewall': {},
        'ip_settings': {},
        'wireless': {},
        'dhcp': {},
        'dns': {},
        'users': {},
        'issues': [],
        'recommendations': []
    }
    
    try:
        # System Information
        print("\n1. Exporting system information...")
        resource = connection.get_resource('/system/identity')
        identity = resource.get()
        if identity:
            config['router_info']['name'] = identity[0].get('name', 'N/A')
        
        resource = connection.get_resource('/system/resource')
        resources = resource.get()
        if resources:
            config['router_info']['version'] = resources[0].get('version', 'N/A')
            config['router_info']['board'] = resources[0].get('board-name', 'N/A')
        
        # Hotspot Configuration
        print("2. Exporting hotspot configuration...")
        resource = connection.get_resource('/ip/hotspot')
        hotspots = resource.get()
        config['hotspot']['servers'] = hotspots
        
        resource = connection.get_resource('/ip/hotspot/profile')
        profiles = resource.get()
        config['hotspot']['profiles'] = profiles
        
        resource = connection.get_resource('/ip/hotspot/user')
        users = resource.get()
        config['hotspot']['users'] = users
        
        # Interfaces
        print("3. Exporting interface configuration...")
        resource = connection.get_resource('/interface')
        interfaces = resource.get()
        config['interfaces']['all'] = interfaces
        
        # Firewall Rules
        print("4. Exporting firewall configuration...")
        resource = connection.get_resource('/ip/firewall/filter')
        filter_rules = resource.get()
        config['firewall']['filter'] = filter_rules
        
        resource = connection.get_resource('/ip/firewall/nat')
        nat_rules = resource.get()
        config['firewall']['nat'] = nat_rules
        
        resource = connection.get_resource('/ip/firewall/mangle')
        mangle_rules = resource.get()
        config['firewall']['mangle'] = mangle_rules
        
        # IP Settings
        print("5. Exporting IP configuration...")
        resource = connection.get_resource('/ip/address')
        addresses = resource.get()
        config['ip_settings']['addresses'] = addresses
        
        resource = connection.get_resource('/ip/route')
        routes = resource.get()
        config['ip_settings']['routes'] = routes
        
        resource = connection.get_resource('/ip/pool')
        pools = resource.get()
        config['ip_settings']['pools'] = pools
        
        # DHCP
        print("6. Exporting DHCP configuration...")
        try:
            resource = connection.get_resource('/ip/dhcp-server')
            dhcp_servers = resource.get()
            config['dhcp']['servers'] = dhcp_servers
        except:
            pass
        
        # DNS
        print("7. Exporting DNS configuration...")
        resource = connection.get_resource('/ip/dns')
        dns = resource.get()
        config['dns'] = dns
        
        # Users
        print("8. Exporting user configuration...")
        resource = connection.get_resource('/user')
        users = resource.get()
        config['users'] = users
        
        print("\n[OK] Configuration exported successfully!")
        
    except Exception as e:
        print(f"[ERROR] Export failed: {str(e)}")
        config['export_error'] = str(e)
    
    return config

def analyze_config(config):
    """Analyze configuration for issues and improvements"""
    print("\n" + "=" * 70)
    print("ANALYZING CONFIGURATION")
    print("=" * 70)
    
    issues = []
    recommendations = []
    
    # Analyze Hotspot
    print("\n1. Analyzing Hotspot Configuration...")
    hotspots = config.get('hotspot', {}).get('servers', [])
    
    for hotspot in hotspots:
        name = hotspot.get('name', 'N/A')
        disabled = hotspot.get('disabled', 'no')
        interface = hotspot.get('interface', '')
        
        if disabled == 'true':
            issues.append({
                'type': 'hotspot',
                'severity': 'high',
                'issue': f"Hotspot '{name}' is disabled",
                'fix': f"Enable hotspot '{name}'"
            })
        
        # Check if interface exists and is enabled
        interfaces = config.get('interfaces', {}).get('all', [])
        interface_found = False
        for iface in interfaces:
            if iface.get('name', '') == interface:
                interface_found = True
                if iface.get('disabled', 'no') == 'true':
                    issues.append({
                        'type': 'interface',
                        'severity': 'high',
                        'issue': f"Hotspot interface '{interface}' is disabled",
                        'fix': f"Enable interface '{interface}'"
                    })
                break
        
        if not interface_found:
            issues.append({
                'type': 'interface',
                'severity': 'critical',
                'issue': f"Hotspot interface '{interface}' not found",
                'fix': f"Create or configure interface '{interface}'"
            })
    
    # Analyze Firewall NAT rules for hotspot
    print("2. Analyzing Firewall NAT Rules...")
    nat_rules = config.get('firewall', {}).get('nat', [])
    
    hotspot_interfaces = [h.get('interface', '') for h in hotspots if h.get('disabled', 'no') == 'no']
    
    for interface in hotspot_interfaces:
        redirect_rules = [r for r in nat_rules if 
                        r.get('chain', '') == 'dstnat' and
                        r.get('action', '') == 'redirect' and
                        r.get('in-interface', '') == interface and
                        r.get('dst-port', '') in ['80', '443']]
        
        if not redirect_rules:
            issues.append({
                'type': 'firewall',
                'severity': 'high',
                'issue': f"Missing hotspot redirect rules for interface '{interface}'",
                'fix': f"Add NAT redirect rules for HTTP/HTTPS on '{interface}'"
            })
        else:
            for rule in redirect_rules:
                if rule.get('disabled', 'no') == 'true':
                    issues.append({
                        'type': 'firewall',
                        'severity': 'high',
                        'issue': f"Hotspot redirect rule is disabled",
                        'fix': f"Enable NAT redirect rule"
                    })
    
    # Analyze IP Pools
    print("3. Analyzing IP Pools...")
    pools = config.get('ip_settings', {}).get('pools', [])
    hotspot_pools = {}
    
    for hotspot in hotspots:
        pool_name = hotspot.get('address-pool', '')
        if pool_name:
            hotspot_pools[hotspot.get('name', '')] = pool_name
    
    for hotspot_name, pool_name in hotspot_pools.items():
        pool_found = False
        for pool in pools:
            if pool.get('name', '') == pool_name:
                pool_found = True
                ranges = pool.get('ranges', '')
                if not ranges:
                    issues.append({
                        'type': 'ip_pool',
                        'severity': 'high',
                        'issue': f"IP Pool '{pool_name}' has no address ranges",
                        'fix': f"Configure address ranges for pool '{pool_name}'"
                    })
                break
        
        if not pool_found:
            issues.append({
                'type': 'ip_pool',
                'severity': 'critical',
                'issue': f"IP Pool '{pool_name}' not found for hotspot '{hotspot_name}'",
                'fix': f"Create IP pool '{pool_name}'"
            })
    
    # Analyze DNS
    print("4. Analyzing DNS Configuration...")
    dns = config.get('dns', {})
    if isinstance(dns, list) and dns:
        dns = dns[0]
    
    if not dns.get('servers') or dns.get('servers') == '':
        recommendations.append({
            'type': 'dns',
            'severity': 'medium',
            'issue': "No DNS servers configured",
            'fix': "Configure DNS servers (e.g., 8.8.8.8, 1.1.1.1)"
        })
    
    # Analyze Firewall Security
    print("5. Analyzing Firewall Security...")
    filter_rules = config.get('firewall', {}).get('filter', [])
    
    # Check for default allow rules that might be insecure
    input_rules = [r for r in filter_rules if r.get('chain', '') == 'input']
    allow_rules = [r for r in input_rules if r.get('action', '') == 'accept']
    
    if len(allow_rules) > 10:
        recommendations.append({
            'type': 'security',
            'severity': 'medium',
            'issue': "Many firewall allow rules - review for security",
            'fix': "Review and restrict firewall rules to minimum necessary"
        })
    
    # Analyze User Security
    print("6. Analyzing User Security...")
    users = config.get('users', [])
    
    for user in users:
        username = user.get('name', 'N/A')
        if username == 'admin':
            # Check if admin has strong password policy
            if user.get('password', ''):
                recommendations.append({
                    'type': 'security',
                    'severity': 'low',
                    'issue': f"Consider using certificate-based authentication for '{username}'",
                    'fix': "Set up SSH keys or certificates for admin access"
                })
    
    # Check for default passwords
    if len(users) == 1 and users[0].get('name') == 'admin':
        recommendations.append({
            'type': 'security',
            'severity': 'medium',
            'issue': "Only default 'admin' user exists",
            'fix': "Create additional user accounts and disable default admin if possible"
        })
    
    config['issues'] = issues
    config['recommendations'] = recommendations
    
    return config

def print_analysis(config):
    """Print analysis results"""
    issues = config.get('issues', [])
    recommendations = config.get('recommendations', [])
    
    print("\n" + "=" * 70)
    print("ANALYSIS RESULTS")
    print("=" * 70)
    
    if issues:
        print(f"\n[ISSUES FOUND: {len(issues)}]")
        print("-" * 70)
        for i, issue in enumerate(issues, 1):
            severity = issue.get('severity', 'unknown').upper()
            print(f"\n{i}. [{severity}] {issue.get('issue', 'N/A')}")
            print(f"   Fix: {issue.get('fix', 'N/A')}")
    else:
        print("\n[OK] No critical issues found!")
    
    if recommendations:
        print(f"\n[RECOMMENDATIONS: {len(recommendations)}]")
        print("-" * 70)
        for i, rec in enumerate(recommendations, 1):
            severity = rec.get('severity', 'unknown').upper()
            print(f"\n{i}. [{severity}] {rec.get('issue', 'N/A')}")
            print(f"   Suggestion: {rec.get('fix', 'N/A')}")
    
    return issues, recommendations

def fix_issues(connection, issues):
    """Automatically fix issues"""
    print("\n" + "=" * 70)
    print("AUTOMATIC FIXES")
    print("=" * 70)
    
    fixed_count = 0
    
    for issue in issues:
        issue_type = issue.get('type', '')
        severity = issue.get('severity', '')
        
        # Only auto-fix high/critical issues
        if severity not in ['high', 'critical']:
            continue
        
        print(f"\nFixing: {issue.get('issue', 'N/A')}")
        
        try:
            if issue_type == 'hotspot':
                # Enable hotspot
                resource = connection.get_resource('/ip/hotspot')
                hotspots = resource.get()
                for hotspot in hotspots:
                    if hotspot.get('name', '') in issue.get('fix', ''):
                        resource.set(id=hotspot.get('.id'), disabled='no')
                        print(f"  [OK] Hotspot enabled")
                        fixed_count += 1
            
            elif issue_type == 'interface':
                # Enable interface
                resource = connection.get_resource('/interface')
                interfaces = resource.get()
                for iface in interfaces:
                    iface_name = iface.get('name', '')
                    if iface_name in issue.get('fix', ''):
                        resource.set(id=iface.get('.id'), disabled='no')
                        print(f"  [OK] Interface '{iface_name}' enabled")
                        fixed_count += 1
            
            elif issue_type == 'firewall':
                # Add or enable NAT redirect rules
                if 'Missing hotspot redirect' in issue.get('issue', ''):
                    # Extract interface from issue
                    interface = issue.get('fix', '').split("'")[1] if "'" in issue.get('fix', '') else ''
                    if interface:
                        resource = connection.get_resource('/ip/firewall/nat')
                        # Check if rules exist but are disabled
                        nat_rules = resource.get()
                        for rule in nat_rules:
                            if (rule.get('in-interface', '') == interface and
                                rule.get('chain', '') == 'dstnat' and
                                rule.get('action', '') == 'redirect' and
                                rule.get('disabled', 'no') == 'true'):
                                resource.set(id=rule.get('.id'), disabled='no')
                                print(f"  [OK] Enabled redirect rule")
                                fixed_count += 1
                        # If no rules exist, add them
                        redirect_rules = [r for r in nat_rules if 
                                         r.get('in-interface', '') == interface and
                                         r.get('chain', '') == 'dstnat' and
                                         r.get('action', '') == 'redirect']
                        if not redirect_rules:
                            # Add HTTP redirect
                            resource.add(
                                chain='dstnat',
                                action='redirect',
                                in_interface=interface,
                                protocol='tcp',
                                dst_port='80',
                                to_ports='80',
                                comment='hotspot-http-redirect'
                            )
                            # Add HTTPS redirect
                            resource.add(
                                chain='dstnat',
                                action='redirect',
                                in_interface=interface,
                                protocol='tcp',
                                dst_port='443',
                                to_ports='80',
                                comment='hotspot-https-redirect'
                            )
                            print(f"  [OK] Added redirect rules for '{interface}'")
                            fixed_count += 1
                elif 'disabled' in issue.get('issue', '').lower():
                    resource = connection.get_resource('/ip/firewall/nat')
                    nat_rules = resource.get()
                    for rule in nat_rules:
                        if (rule.get('chain', '') == 'dstnat' and
                            rule.get('action', '') == 'redirect' and
                            rule.get('disabled', 'no') == 'true'):
                            resource.set(id=rule.get('.id'), disabled='no')
                            print(f"  [OK] Enabled redirect rule")
                            fixed_count += 1
            
        except Exception as e:
            print(f"  [ERROR] Failed to fix: {str(e)}")
    
    print(f"\n[SUMMARY] Fixed {fixed_count} issue(s) automatically")
    return fixed_count

def save_config(config, filename='router_config_export.json'):
    """Save configuration to file"""
    try:
        # Convert to JSON-serializable format
        json_config = json.dumps(config, indent=2, default=str)
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(json_config)
        
        print(f"\n[OK] Configuration saved to: {filename}")
        return filename
    except Exception as e:
        print(f"[ERROR] Failed to save config: {str(e)}")
        return None

def main():
    """Main function"""
    try:
        print(f"Connecting to {HOST}...")
        connection = connect(HOST, username=USERNAME, password=PASSWORD, port=PORT, plaintext_login=True)
        print("[OK] Connected\n")
        
        # Export configuration
        config = export_config(connection)
        
        # Analyze configuration
        config = analyze_config(config)
        
        # Print analysis
        issues, recommendations = print_analysis(config)
        
        # Save configuration
        filename = save_config(config)
        
        # Auto-fix issues
        if issues:
            print("\n" + "=" * 70)
            print("AUTO-FIXING ISSUES")
            print("=" * 70)
            fixed = fix_issues(connection, issues)
            
            if fixed > 0:
                print("\n[INFO] Re-running analysis after fixes...")
                config = export_config(connection)
                config = analyze_config(config)
                issues, recommendations = print_analysis(config)
        
        # Ask about recommendations
        if recommendations:
            print("\n" + "=" * 70)
            print("RECOMMENDATIONS FOR IMPROVEMENT")
            print("=" * 70)
            print("\nThe following improvements are suggested:")
            for i, rec in enumerate(recommendations, 1):
                print(f"\n{i}. [{rec.get('severity', 'unknown').upper()}] {rec.get('issue', 'N/A')}")
                print(f"   {rec.get('fix', 'N/A')}")
            
            print("\n" + "=" * 70)
            print("\nTo apply recommendations, run: python apply_recommendations.py")
            print("Or review the recommendations in the exported config file.")
            
            # For non-interactive mode, skip auto-apply
            try:
                response = input("\nWould you like me to apply these recommendations? (yes/no): ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print("\n[INFO] Running in non-interactive mode. Recommendations saved to config file.")
                response = 'no'
            
            if response in ['yes', 'y']:
                print("\nApplying recommendations...")
                # Apply recommendations (implement based on type)
                for rec in recommendations:
                    rec_type = rec.get('type', '')
                    if rec_type == 'dns':
                        # Configure DNS
                        resource = connection.get_resource('/ip/dns')
                        dns_config = resource.get()
                        if dns_config:
                            resource.set(id=dns_config[0].get('.id'), servers='8.8.8.8,1.1.1.1')
                            print(f"  [OK] Configured DNS servers")
                    # Add more recommendation implementations as needed
            else:
                print("\n[INFO] Recommendations not applied. You can review them in the exported config file.")
        
        print("\n" + "=" * 70)
        print("ANALYSIS COMPLETE")
        print("=" * 70)
        print(f"\nConfiguration exported to: {filename}")
        print("Review the file for detailed configuration information.")
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()

