#!/usr/bin/env python3
"""
Enable RouterOS API Service on Port 8728
This script provides multiple methods to enable the API service
"""

print("=" * 60)
print("Enable RouterOS API Service on Port 8728")
print("=" * 60)
print("\nMETHOD 1: Manual via Winbox/WebFig")
print("-" * 60)
print("1. Connect to router via Winbox (port 8291) or WebFig (http://10.1.1.1)")
print("2. Go to: IP > Services")
print("3. Find the 'api' service in the list")
print("4. Double-click it or click 'Edit'")
print("5. Set Port: 8728")
print("6. Check 'Enabled' checkbox")
print("7. Click OK")
print("\nMETHOD 2: RouterOS Terminal Commands")
print("-" * 60)
print("Copy and paste these commands into RouterOS Terminal:")
print()
print("/ip service set [find name=api] port=8728")
print("/ip service enable api")
print("/ip service print where name=api")
print()
print("METHOD 3: Using enable_api_commands.txt")
print("-" * 60)
print("See enable_api_commands.txt for the commands")
print()
print("=" * 60)
print("\nAfter enabling, test the connection with:")
print("  python routeros_connect.py")
print("=" * 60)

