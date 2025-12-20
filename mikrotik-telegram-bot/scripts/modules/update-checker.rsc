#\!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# RouterOS Update Checker Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Check for RouterOS updates and notify via Telegram
# Inspired by eworm-de/routeros-scripts check-routeros-update
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ( \!= true) do={ :error "Config not loaded"; }; } delay=500ms max=50;

  :local ScriptName [:jobname];

  # Load dependencies
  :global SharedFunctionsLoaded;
  :if ( \!= true) do={
    :onerror e { /system script run "modules/shared-functions"; } do={}
  }
  :global TelegramAPILoaded;
  :if ( \!= true) do={
    :onerror e { /system script run "modules/telegram-api"; } do={}
  }

  # Import functions
  :global SendTelegram2;
  :global SaveBotState;
  :global LoadBotState;
  :global VersionToNum;
  :global CompareVersions;

  # Import config
  :global Identity;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableUpdateChecker;
  :global UpdateChannel;
  :global AutoInstallPatches;

  # Default config values
  :if ([:typeof ] \!= "bool") do={ :set EnableUpdateChecker true; }
  :if ([:typeof ] \!= "str") do={ :set UpdateChannel "stable"; }
  :if ([:typeof ] \!= "bool") do={ :set AutoInstallPatches false; }

  :if ( \!= true) do={
    :log debug "update-checker - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # ═══════════════════════════════════════════════════════════════
  # CHECK FOR UPDATES
  # ═══════════════════════════════════════════════════════════════

  # Get current version
  :local CurrentVersion [/system resource get version];
  :local CurrentVersionNum [ ];

  # Check for updates
  :log info "update-checker - Checking for updates...";
  /system/package/update/set channel=;
  /system/package/update/check-for-updates;
  :delay 3s;

  :local LatestVersion [/system/package/update get latest-version];
  :local InstalledVersion [/system/package/update get installed-version];
  :local UpdateStatus [/system/package/update get status];

  :if ([:len ] = 0) do={
    :log warning "update-checker - Could not check for updates";
    :set ExitOK true;
    :error "Check failed";
  }

  :local LatestVersionNum [ ];
  :local InstalledVersionNum [ ];

  # Load previous state
  :global UpdateCheckerState;
  :if ([:typeof ] \!= "array") do={
    :local Loaded [ "update-checker"];
    :if ([:typeof ] = "array") do={
      :set UpdateCheckerState ;
    } else={
      :set UpdateCheckerState ({"lastNotified"=""; "lastVersion"=""});
    }
  }

  :local LastNotified (->"lastNotified");
  :local LastVersion (->"lastVersion");

  # Compare versions
  :if ( > ) do={
    # Check if already notified for this version
    :if ( \!= ) do={
      :log info ("update-checker - New version available: " . );

      # Determine if patch or feature update
      :local IsPatch false;
      :local InstalledMajor [:pick  0 [:find  "."]];
      :local LatestMajor [:pick  0 [:find  "."]];
      :if ( = ) do={
        :set IsPatch true;
      }

      :local UpdateType "Feature Update";
      :if ( = true) do={
        :set UpdateType "Patch Update";
      }

      # Send notification
       ({
        chatid=;
        threadid=;
        silent=false;
        subject=("[" .  . "] RouterOS Update Available");
        message=("Type: " .  . "\nCurrent: " .  . "\nLatest: " .  . "\nChannel: " .  . "\n\nUse /system/package/update/install to update")
      });

      # Update state
      :set (->"lastNotified") [:tostr [/system clock get time]];
      :set (->"lastVersion") ;
       "update-checker" ;

      # Auto-install patches if enabled
      :if ( = true &&  = true) do={
        :log warning "update-checker - Auto-installing patch update...";
         ({
          chatid=;
          threadid=;
          silent=false;
          subject=("[" .  . "] Installing Patch");
          message=("Auto-installing patch " .  . "...\nRouter will reboot.")
        });
        :delay 5s;
        /system/package/update/install;
      }
    } else={
      :log debug "update-checker - Already notified for this version";
    }
  } else={
    :log debug "update-checker - System is up to date";
  }

  :set ExitOK true;
} do={
  :if ( = false) do={
    :log error ([:jobname] . " - Script failed: " . );
  }
}

:global UpdateCheckerLoaded true;
:log info "Update checker module loaded"
