#!/bin/bash
# Correct git mv commands using relative paths (workspace/ instead of /workspace/)
# Run this from D:/AI/Agent directory

# Create destination directory if it doesn't exist
mkdir -p archive/legacy-scripts

# Move files using relative paths (workspace/ not /workspace/)
git mv workspace/add_hotspot_redirect.py archive/legacy-scripts/
git mv workspace/analyze_and_fix_export.py archive/legacy-scripts/
git mv workspace/apply_all_fixes.py archive/legacy-scripts/
git mv workspace/check_hotspot.py archive/legacy-scripts/
git mv workspace/check_router_ports.py archive/legacy-scripts/
git mv workspace/check_wifi_ssid.py archive/legacy-scripts/
git mv workspace/comprehensive_fix.py archive/legacy-scripts/
git mv workspace/CONFIGURATION_SUMMARY.md archive/legacy-scripts/
git mv workspace/CORRECTED_FIX.md archive/legacy-scripts/
git mv workspace/enable_api_commands.txt archive/legacy-scripts/
git mv workspace/enable_api_via_ssh.py archive/legacy-scripts/
git mv workspace/enable_api_web.py archive/legacy-scripts/
git mv workspace/enable_api.py archive/legacy-scripts/
git mv workspace/enable_hotspot.py archive/legacy-scripts/
git mv workspace/export_and_analyze.py archive/legacy-scripts/
git mv workspace/fix_hotspot_commands.txt archive/legacy-scripts/
git mv workspace/fix_hotspot_correct.py archive/legacy-scripts/
git mv workspace/fix_hotspot_login.py archive/legacy-scripts/
git mv workspace/fix_hotspot.py archive/legacy-scripts/
git mv workspace/FIX_SUMMARY.md archive/legacy-scripts/
git mv workspace/generate_report.py archive/legacy-scripts/
git mv workspace/README_FIXES.md archive/legacy-scripts/
git mv workspace/requirements.txt archive/legacy-scripts/
git mv workspace/ROLLBACK_COMMANDS.txt archive/legacy-scripts/
git mv workspace/router_analysis_report.txt archive/legacy-scripts/
git mv workspace/router_config_export.json archive/legacy-scripts/
git mv workspace/routeros_connect.py archive/legacy-scripts/
git mv workspace/routeros_examples.py archive/legacy-scripts/
git mv workspace/safe_fix_hotspot.py archive/legacy-scripts/
git mv workspace/SAFETY_GUIDE.md archive/legacy-scripts/
git mv workspace/test_connection_advanced.py archive/legacy-scripts/
git mv workspace/test_connection.py archive/legacy-scripts/
git mv workspace/verify_and_fix.py archive/legacy-scripts/

