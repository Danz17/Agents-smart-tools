# PowerShell script to move workspace files to archive/legacy-scripts
# Using relative paths (workspace/ instead of /workspace/)

$sourceDir = "D:\AI\Agent\workspace"
$destDir = "D:\AI\Agent\archive\legacy-scripts"

# Create destination if it doesn't exist
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# List of files to move (relative to workspace directory)
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

# Change to repository root
Set-Location "D:\AI\Agent"

# Move each file using git mv with relative paths
foreach ($file in $files) {
    $sourcePath = "workspace\$file"
    $destPath = "archive\legacy-scripts\$file"
    
    if (Test-Path $sourcePath) {
        Write-Host "Moving: $sourcePath -> $destPath"
        git mv $sourcePath $destPath
    } else {
        Write-Host "File not found: $sourcePath" -ForegroundColor Yellow
    }
}

Write-Host "`nDone! Files moved to archive/legacy-scripts/" -ForegroundColor Green

