#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# User Settings Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Persistent user preferences per chat ID
# Dependencies: shared-functions

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr { /system script run "modules/shared-functions"; } do={ }
}

# Import functions
:global SaveBotState;
:global LoadBotState;

# ============================================================================
# DEFAULT SETTINGS
# ============================================================================

:global GetDefaultSettings do={
  :return ({
    notification_style="alert";
    message_cleanup_enabled=true;
    message_retention_hours=24;
    command_aliases=({});
    preferred_language="en";
    timezone="";
    auto_confirm=false;
    compact_mode=false
  });
}

# ============================================================================
# GET USER SETTING
# ============================================================================

:global GetUserSetting do={
  :local ChatId [ :tostr $1 ];
  :local SettingKey [ :tostr $2 ];
  :local DefaultValue $3;
  
  :local Settings [$GetUserSettings $ChatId];
  :if ([:typeof ($Settings->$SettingKey)] != "nothing") do={
    :return ($Settings->$SettingKey);
  }
  :return $DefaultValue;
}

# ============================================================================
# SET USER SETTING
# ============================================================================

:global SetUserSetting do={
  :local ChatId [ :tostr $1 ];
  :local SettingKey [ :tostr $2 ];
  :local SettingValue $3;
  
  :local Settings [$GetUserSettings $ChatId];
  :set ($Settings->$SettingKey) $SettingValue;
  
  :local SettingsFile ("tmpfs/bot-user-settings-" . $ChatId . ".txt");
  :onerror SaveErr {
    :local JSON [ :serialize to=json value=$Settings ];
    /file/add name=$SettingsFile contents=$JSON;
    :log debug ("user-settings - Saved setting for user " . $ChatId . ": " . $SettingKey);
    :return true;
  } do={
    :log warning ("user-settings - Failed to save setting: " . $SaveErr);
    :return false;
  }
}

# ============================================================================
# GET ALL USER SETTINGS
# ============================================================================

:global GetUserSettings do={
  :local ChatId [ :tostr $1 ];
  :local SettingsFile ("tmpfs/bot-user-settings-" . $ChatId . ".txt");
  
  :onerror LoadErr {
    :if ([:len [/file find name=$SettingsFile]] > 0) do={
      :local SettingsData ([/file get $SettingsFile contents]);
      :if ([:len $SettingsData] > 0) do={
        :local LoadedSettings [ :deserialize from=json value=$SettingsData ];
        :if ([:typeof $LoadedSettings] = "array") do={
          :return $LoadedSettings;
        }
      }
    }
  } do={ }
  
  # Return defaults if no settings found
  :return [$GetDefaultSettings];
}

# ============================================================================
# RESET USER SETTINGS
# ============================================================================

:global ResetUserSettings do={
  :local ChatId [ :tostr $1 ];
  :local SettingsFile ("tmpfs/bot-user-settings-" . $ChatId . ".txt");
  
  :onerror DelErr {
    :if ([:len [/file find name=$SettingsFile]] > 0) do={
      /file remove $SettingsFile;
    }
    :log info ("user-settings - Reset settings for user " . $ChatId);
    :return true;
  } do={
    :log warning ("user-settings - Failed to reset settings: " . $DelErr);
    :return false;
  }
}

# ============================================================================
# GET NOTIFICATION STYLE
# ============================================================================

:global GetUserNotificationStyle do={
  :local ChatId [ :tostr $1 ];
  :local Style [$GetUserSetting $ChatId "notification_style" "alert"];
  :if ($Style = "silent") do={
    :return true;
  }
  :return false;
}

# ============================================================================
# GET MESSAGE CLEANUP PREFERENCE
# ============================================================================

:global GetUserMessageCleanup do={
  :local ChatId [ :tostr $1 ];
  :return [$GetUserSetting $ChatId "message_cleanup_enabled" true];
}

# ============================================================================
# GET MESSAGE RETENTION
# ============================================================================

:global GetUserMessageRetention do={
  :local ChatId [ :tostr $1 ];
  :return [$GetUserSetting $ChatId "message_retention_hours" 24];
}

# ============================================================================
# GET COMMAND ALIASES
# ============================================================================

:global GetUserCommandAliases do={
  :local ChatId [ :tostr $1 ];
  :local Aliases [$GetUserSetting $ChatId "command_aliases" ({})];
  :if ([:typeof $Aliases] != "array") do={
    :return ({});
  }
  :return $Aliases;
}

# ============================================================================
# SET COMMAND ALIAS
# ============================================================================

:global SetUserCommandAlias do={
  :local ChatId [ :tostr $1 ];
  :local Alias [ :tostr $2 ];
  :local Command [ :tostr $3 ];
  
  :local Aliases [$GetUserCommandAliases $ChatId];
  :set ($Aliases->$Alias) $Command;
  [$SetUserSetting $ChatId "command_aliases" $Aliases];
  :return true;
}

# ============================================================================
# REMOVE COMMAND ALIAS
# ============================================================================

:global RemoveUserCommandAlias do={
  :local ChatId [ :tostr $1 ];
  :local Alias [ :tostr $2 ];
  
  :local Aliases [$GetUserCommandAliases $ChatId];
  :if ([:typeof ($Aliases->$Alias)] != "nothing") do={
    :set ($Aliases->$Alias) "";
    [$SetUserSetting $ChatId "command_aliases" $Aliases];
    :return true;
  }
  :return false;
}

# ============================================================================
# FORMAT SETTINGS FOR DISPLAY
# ============================================================================

:global FormatUserSettings do={
  :local ChatId [ :tostr $1 ];
  :local Settings [$GetUserSettings $ChatId];
  
  :local Text ("*⚡ TxMTC Settings*\n\n");
  
  :local NotifStyle ($Settings->"notification_style");
  :set Text ($Text . "🔔 Notifications: " . $NotifStyle . "\n");
  
  :local CleanupEnabled ($Settings->"message_cleanup_enabled");
  :if ($CleanupEnabled = true) do={
    :set Text ($Text . "🧹 Auto-cleanup: Enabled\n");
    :local Retention ($Settings->"message_retention_hours");
    :set Text ($Text . "⏰ Retention: " . $Retention . " hours\n");
  } else={
    :set Text ($Text . "🧹 Auto-cleanup: Disabled\n");
  }
  
  :local Aliases ($Settings->"command_aliases");
  :if ([:len $Aliases] > 0) do={
    :set Text ($Text . "\n📝 Command Aliases:\n");
    :foreach Alias,Command in=$Aliases do={
      :if ([:len $Command] > 0) do={
        :set Text ($Text . "  `" . $Alias . "` → `" . $Command . "`\n");
      }
    }
  }
  
  :local CompactMode ($Settings->"compact_mode");
  :if ($CompactMode = true) do={
    :set Text ($Text . "\n📱 Compact Mode: Enabled\n");
  }
  
  :return $Text;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global UserSettingsLoaded true;
:log info "User settings module loaded"
