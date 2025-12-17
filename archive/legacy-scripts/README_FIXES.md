# Hotspot Login Fix - Instructions

## Problem
The "bawal balik" WiFi hotspot is allowing unlimited internet access without requiring login.

## Solution
Apply firewall rules to block unauthenticated traffic and force users to login.

## Method 1: Using RouterOS API (When router is accessible)

Run the comprehensive fix script:
```bash
python comprehensive_fix.py
```

This script will:
1. ✅ Fix hotspot login enforcement
2. ✅ Review firewall rules
3. ✅ Configure DNS
4. ✅ Apply all improvements

## Method 2: Using RouterOS Commands (Direct)

If the API is not accessible, use the commands in `fix_hotspot_commands.txt`:

1. Connect to router via:
   - **Winbox** (port 8291)
   - **WebFig** (http://10.1.1.1)
   - **SSH** (port 22)

2. Open Terminal/Console

3. Copy and paste commands from `fix_hotspot_commands.txt`

## What the Fix Does

### 1. Blocks Unauthenticated Traffic
- Adds firewall rule to drop all traffic from hotspot interface for users who haven't authenticated
- Uses `hotspot=!auth` condition

### 2. Allows Authenticated Traffic
- Allows established/related connections for authenticated users
- Uses `hotspot=auth` condition

### 3. Ensures Redirect Rules
- Verifies HTTP (port 80) redirect rule exists
- Verifies HTTPS (port 443) redirect rule exists
- These redirect users to login page

### 4. Enables Hotspot
- Ensures hotspot server is enabled
- Ensures interface is enabled

## Expected Result

After applying the fix:
- ✅ Users connecting to "bawal balik" WiFi cannot access internet
- ✅ Opening a browser redirects to hotspot login page
- ✅ Users must authenticate before getting internet access
- ✅ Authenticated users can browse normally

## Testing

1. Connect a device to "bawal balik" WiFi
2. Try to open any website
3. Should be redirected to MikroTik hotspot login page
4. Enter credentials
5. After login, internet should work

## Troubleshooting

If users still have internet without login:

1. Check firewall rules are in correct order:
   ```bash
   /ip firewall filter print where in-interface=wifi2-hotspot
   ```
   The blocking rule should be near the top (lower number)

2. Verify hotspot is enabled:
   ```bash
   /ip hotspot print
   ```

3. Check NAT redirect rules:
   ```bash
   /ip firewall nat print where in-interface=wifi2-hotspot
   ```

4. Verify interface is enabled:
   ```bash
   /interface print where name=wifi2-hotspot
   ```

## Files

- `comprehensive_fix.py` - Automated fix script (requires API access)
- `fix_hotspot_commands.txt` - Manual RouterOS commands
- `fix_hotspot_login.py` - Detailed hotspot login fix script

