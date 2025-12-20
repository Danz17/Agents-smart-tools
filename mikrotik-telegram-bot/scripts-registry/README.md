# TxMTC Script Registry

This directory contains the script registry data for the TxMTC bot.

## Registry Format

The `registry.json` file contains metadata for available scripts that can be installed via the bot.

### Script Entry Structure

```json
{
  "script-id": {
    "name": "Script Display Name",
    "category": "monitoring|backup|utilities|parental-control|network-management|misc",
    "description": "Brief description of what the script does",
    "version": "1.0.0",
    "source": "https://raw.githubusercontent.com/.../script.rsc or local",
    "dependencies": ["module1", "module2"],
    "critical": false
  }
}
```

## Categories

- **monitoring**: System health, updates, alerts
- **backup**: Backup and restore scripts
- **utilities**: PoE, USB, general utilities
- **parental-control**: Kid control, access management
- **network-management**: DHCP, DNS, routing scripts
- **misc**: Other scripts

## Adding Scripts

To add a new script to the registry:

1. Edit `registry.json`
2. Add a new entry with unique script ID
3. Fill in all required fields
4. Commit and push to repository

The bot will automatically fetch updated registry when `UpdateScriptRegistry` is called.

## Source Types

- **Remote URL**: Script will be downloaded from the URL
- **local**: Script must be manually installed or already exists on router

## Dependencies

List any required modules or scripts that must be installed first. The bot will check for these before installation.
