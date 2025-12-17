#!/usr/bin/env python3
"""
Generate detailed analysis report from exported configuration
"""

import json
import os

def generate_report():
    """Generate human-readable report from exported config"""
    
    if not os.path.exists('router_config_export.json'):
        print("[ERROR] router_config_export.json not found. Run export_and_analyze.py first.")
        return
    
    with open('router_config_export.json', 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    print("=" * 70)
    print("MIKROTIK ROUTER CONFIGURATION ANALYSIS REPORT")
    print("=" * 70)
    
    # Router Info
    router_info = config.get('router_info', {})
    print(f"\nRouter Name: {router_info.get('name', 'N/A')}")
    print(f"RouterOS Version: {router_info.get('version', 'N/A')}")
    print(f"Board: {router_info.get('board', 'N/A')}")
    print(f"Export Date: {config.get('export_date', 'N/A')}")
    
    # Issues
    issues = config.get('issues', [])
    print("\n" + "=" * 70)
    print(f"ISSUES FOUND: {len(issues)}")
    print("=" * 70)
    
    if issues:
        critical = [i for i in issues if i.get('severity') == 'critical']
        high = [i for i in issues if i.get('severity') == 'high']
        medium = [i for i in issues if i.get('severity') == 'medium']
        
        if critical:
            print(f"\n[CRITICAL: {len(critical)}]")
            for issue in critical:
                print(f"  - {issue.get('issue', 'N/A')}")
                print(f"    Fix: {issue.get('fix', 'N/A')}")
        
        if high:
            print(f"\n[HIGH: {len(high)}]")
            for issue in high:
                print(f"  - {issue.get('issue', 'N/A')}")
                print(f"    Fix: {issue.get('fix', 'N/A')}")
        
        if medium:
            print(f"\n[MEDIUM: {len(medium)}]")
            for issue in medium:
                print(f"  - {issue.get('issue', 'N/A')}")
                print(f"    Fix: {issue.get('fix', 'N/A')}")
    else:
        print("\n[OK] No issues found!")
    
    # Recommendations
    recommendations = config.get('recommendations', [])
    print("\n" + "=" * 70)
    print(f"RECOMMENDATIONS: {len(recommendations)}")
    print("=" * 70)
    
    if recommendations:
        for i, rec in enumerate(recommendations, 1):
            severity = rec.get('severity', 'unknown').upper()
            print(f"\n{i}. [{severity}] {rec.get('issue', 'N/A')}")
            print(f"   Suggestion: {rec.get('fix', 'N/A')}")
    else:
        print("\n[OK] No recommendations at this time.")
    
    # Configuration Summary
    print("\n" + "=" * 70)
    print("CONFIGURATION SUMMARY")
    print("=" * 70)
    
    hotspots = config.get('hotspot', {}).get('servers', [])
    print(f"\nHotspot Servers: {len(hotspots)}")
    for hotspot in hotspots:
        print(f"  - {hotspot.get('name', 'N/A')} on {hotspot.get('interface', 'N/A')} ({'Enabled' if hotspot.get('disabled', 'no') == 'no' else 'Disabled'})")
    
    filter_rules = config.get('firewall', {}).get('filter', [])
    nat_rules = config.get('firewall', {}).get('nat', [])
    print(f"\nFirewall Rules:")
    print(f"  - Filter Rules: {len(filter_rules)}")
    print(f"  - NAT Rules: {len(nat_rules)}")
    
    interfaces = config.get('interfaces', {}).get('all', [])
    enabled_interfaces = [i for i in interfaces if i.get('disabled', 'no') == 'no']
    print(f"\nInterfaces:")
    print(f"  - Total: {len(interfaces)}")
    print(f"  - Enabled: {len(enabled_interfaces)}")
    
    users = config.get('users', [])
    print(f"\nUsers: {len(users)}")
    for user in users:
        print(f"  - {user.get('name', 'N/A')} (Groups: {user.get('group', 'N/A')})")
    
    # Save report to file
    report_file = 'router_analysis_report.txt'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("=" * 70 + "\n")
        f.write("MIKROTIK ROUTER CONFIGURATION ANALYSIS REPORT\n")
        f.write("=" * 70 + "\n\n")
        f.write(f"Router: {router_info.get('name', 'N/A')}\n")
        f.write(f"Version: {router_info.get('version', 'N/A')}\n")
        f.write(f"Export Date: {config.get('export_date', 'N/A')}\n\n")
        f.write(f"Issues: {len(issues)}\n")
        f.write(f"Recommendations: {len(recommendations)}\n")
    
    print(f"\n[OK] Detailed report saved to: {report_file}")
    print(f"[OK] Full configuration saved to: router_config_export.json")

if __name__ == "__main__":
    generate_report()


