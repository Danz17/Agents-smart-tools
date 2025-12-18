# PowerShell script - Correct git mv commands using relative paths
# Run from D:\AI\Agent directory

# Create destination directory
New-Item -ItemType Directory -Path "archive\legacy-scripts" -Force | Out-Null

# Change to repository root
Set-Location "D:\AI\Agent"

# Move files using relative paths (workspace\ not \workspace\)
# Note: Use forward slashes or escaped backslashes for git commands
$files = @(
    "add_hotspot_redirect.py",
    "analyze_and_fix_export.py",
    "apply_all_fixes.py",
    "check_hotspot.py",
    "check_router_ports.py",
    "check_wifi_ssid.py",
    "comprehensive_fix.py",
    "CONFIGURATION_SUMMARY.md",
    "CORRECTED_FIX.md",
    "enable_api_commands.txt",
    "enable_api_via_ssh.py",
    "enable_api_web.py",
    "enable_api.py",
    "enable_hotspot.py",
    "export_and_analyze.py",
    "fix_hotspot_commands.txt",
    "fix_hotspot_correct.py",
    "fix_hotspot_login.py",
    "fix_hotspot.py",
    "FIX_SUMMARY.md",
    "generate_report.py",
    "README_FIXES.md",
    "requirements.txt",
    "ROLLBACK_COMMANDS.txt",
    "router_analysis_report.txt",
    "router_config_export.json",
    "routeros_connect.py",
    "routeros_examples.py",
    "safe_fix_hotspot.py",
    "SAFETY_GUIDE.md",
    "test_connection_advanced.py",
    "test_connection.py",
    "verify_and_fix.py"
)

foreach ($file in $files) {
    $source = "workspace/$file"  # Relative path with forward slash for git
    $dest = "archive/legacy-scripts/$file"
    
    if (Test-Path "workspace\$file") {
        Write-Host "Moving: $source -> $dest"
        git mv $source $dest
    } else {
        Write-Host "File not found: workspace\$file" -ForegroundColor Yellow
    }
}

Write-Host "`nDone! Use relative paths: workspace/ not /workspace/" -ForegroundColor Green

