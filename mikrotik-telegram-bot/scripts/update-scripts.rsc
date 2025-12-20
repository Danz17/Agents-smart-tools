#!rsc by RouterOS
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Script Updater / Auto-Updater
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Phenix | Version: 2.1.1

:local ScriptName "update-scripts";

# Configuration
:local GitHubUser "Danz17";
:local GitHubRepo "Agents-smart-tools";
:local GitHubBranch "main";
:local GitHubPath "mikrotik-telegram-bot/scripts";
:local BaseURL ("https://raw.githubusercontent.com/" . $GitHubUser . "/" . $GitHubRepo . "/" . $GitHubBranch . "/" . $GitHubPath);
:local VersionURL ($BaseURL . "/version.txt");

# Local version tracking
:global TxMTCVersion;
:if ([:typeof $TxMTCVersion] != "str") do={ :set TxMTCVersion "0.0.0"; }

# Auto-update settings
:global AutoUpdateEnabled;
:global AutoUpdateInterval;
:global AutoUpdateNotify;
:if ([:typeof $AutoUpdateEnabled] != "bool") do={ :set AutoUpdateEnabled true; }
:if ([:typeof $AutoUpdateInterval] != "str") do={ :set AutoUpdateInterval "1h"; }
:if ([:typeof $AutoUpdateNotify] != "bool") do={ :set AutoUpdateNotify true; }

# Silent mode detection
:local SilentMode false;
:local JobName [ :jobname ];
:if ($JobName ~ "scheduler") do={ :set SilentMode true; }

# Local script prefix detection
:local LocalPrefix "";
:onerror DetectErr {
  :local ExistingScript [ /system/script/find where name~"bot-core" ];
  :if ([:len $ExistingScript] > 0) do={
    :local ExistingName [ /system/script/get $ExistingScript name ];
    :local CorePos [:find $ExistingName "bot-core"];
    :if ([:typeof $CorePos] = "num" && $CorePos > 0) do={
      :set LocalPrefix [:pick $ExistingName 0 $CorePos];
    }
  }
} do={ }

# Version check
:local RemoteVersion "";
:local UpdateAvailable false;

:onerror VersionErr {
  :local VersionData ([ /tool/fetch check-certificate=yes-without-crl $VersionURL output=user as-value ]->"data");
  :set RemoteVersion "";
  :for I from=0 to=([:len $VersionData] - 1) do={
    :local Char [:pick $VersionData $I ($I + 1)];
    :if ($Char ~ "[0-9.]") do={ :set RemoteVersion ($RemoteVersion . $Char); }
  }
  :if ($RemoteVersion != $TxMTCVersion && [:len $RemoteVersion] > 0) do={ :set UpdateAvailable true; }
} do={
  :if ($SilentMode = false) do={ :put ("Version check failed: " . $VersionErr); }
  :log warning ("update-scripts - Version check failed: " . $VersionErr);
}

# Exit if no update needed
:if ($UpdateAvailable = false && $SilentMode = true) do={
  :log debug "update-scripts - No updates available";
  :return "no-updates";
}
:if ($UpdateAvailable = false && $SilentMode = false) do={
  :put "+===============================================================+";
  :put "|  TxMTC - Up to date!                                          |";
  :local VersionInfo ("  Current: " . $TxMTCVersion);
  :if ([:len $RemoteVersion] > 0) do={ :set VersionInfo ($VersionInfo . " | Remote: " . $RemoteVersion); }
  :put $VersionInfo;
  :put "+===============================================================+";
  :put "";
  :return "no-updates";
}

# Update scripts
:if ($SilentMode = false) do={
  :put "+===============================================================+";
  :put ("  Updating: " . $TxMTCVersion . " -> " . $RemoteVersion);
  :put "+===============================================================+";
}
:log info ("update-scripts - Updating from " . $TxMTCVersion . " to " . $RemoteVersion);

:local ScriptList {
  "bot-config"="bot-config.rsc";
  "modules/shared-functions"="modules/shared-functions.rsc";
  "modules/telegram-api"="modules/telegram-api.rsc";
  "modules/security"="modules/security.rsc";
  "modules/script-registry"="modules/script-registry.rsc";
  "modules/interactive-menu"="modules/interactive-menu.rsc";
  "modules/user-settings"="modules/user-settings.rsc";
  "modules/script-discovery"="modules/script-discovery.rsc";
  "bot-core"="bot-core.rsc";
  "modules/backup"="modules/backup.rsc";
  "modules/monitoring"="modules/monitoring.rsc";
  "modules/custom-commands"="modules/custom-commands.rsc";
  "modules/wireless-monitoring"="modules/wireless-monitoring.rsc";
  "modules/daily-summary"="modules/daily-summary.rsc";
  "set-credentials"="set-credentials.rsc";
  "load-credentials-from-file"="load-credentials-from-file.rsc";
  "update-scripts"="update-scripts.rsc"
};

:local UpdateCount 0;
:local CreateCount 0;
:local FailCount 0;

:foreach ScriptItem,FilePath in=$ScriptList do={
  :local URL ($BaseURL . "/" . $FilePath);
  :local FullScriptName ($LocalPrefix . $ScriptItem);
  :if ($SilentMode = false) do={ :put ("Processing: " . $FullScriptName); }

  :onerror FetchError {
    :local ScriptContent ([ /tool/fetch check-certificate=yes-without-crl $URL output=user as-value ]->"data");
    :if ([:len $ScriptContent] > 100) do={
      :local ExistingScript [ /system/script/find where name=$FullScriptName ];
      :if ([:len $ExistingScript] = 0) do={ :set ExistingScript [ /system/script/find where name~$ScriptItem ]; }
      :if ([:len $ExistingScript] > 0) do={
        :local TargetScript [:pick $ExistingScript 0];
        /system/script/set $TargetScript source=$ScriptContent;
        :if ($SilentMode = false) do={ :put ("  Updated: " . $FullScriptName); }
        :set UpdateCount ($UpdateCount + 1);
      } else={
        /system/script/add name=$FullScriptName owner=admin policy=ftp,read,write,policy,test,password,sniff,sensitive,romon source=$ScriptContent;
        :if ($SilentMode = false) do={ :put ("  Created: " . $FullScriptName); }
        :set CreateCount ($CreateCount + 1);
      }
    } else={
      :if ($SilentMode = false) do={ :put ("  FAILED: Empty content"); }
      :set FailCount ($FailCount + 1);
    }
  } do={
    :if ($SilentMode = false) do={ :put ("  FAILED: " . $FetchError); }
    :set FailCount ($FailCount + 1);
  }
}

:if ($FailCount = 0) do={ :set TxMTCVersion $RemoteVersion; }

# Clear module caches
:global SharedFunctionsLoaded; :set SharedFunctionsLoaded;
:global TelegramAPILoaded; :set TelegramAPILoaded;
:global SecurityModuleLoaded; :set SecurityModuleLoaded;
:global ScriptRegistryLoaded; :set ScriptRegistryLoaded;
:global InteractiveMenuLoaded; :set InteractiveMenuLoaded;
:global UserSettingsLoaded; :set UserSettingsLoaded;
:global ScriptDiscoveryLoaded; :set ScriptDiscoveryLoaded;

# Results
:if ($SilentMode = false) do={
  :put "+---------------------------------------------------------------+";
  :put ("| Updated: " . $UpdateCount . " | Created: " . $CreateCount . " | Failed: " . $FailCount);
  :put ("| Version: " . $TxMTCVersion);
  :put "+---------------------------------------------------------------+";
}
:log info ("update-scripts - Complete: " . $UpdateCount . " updated, " . $CreateCount . " created, " . $FailCount . " failed");

# Telegram notification
:if ($AutoUpdateNotify = true && $FailCount = 0 && ($UpdateCount + $CreateCount) > 0) do={
  :global SendTelegram2;
  :global TelegramChatId;
  :if ([:typeof $SendTelegram2] != "nothing" && [:typeof $TelegramChatId] = "str") do={
    $SendTelegram2 ({chatid=$TelegramChatId; silent=true; subject="TxMTC Auto-Update"; message=("Updated to v" . $TxMTCVersion)});
  }
}

# Setup auto-update scheduler
:global SetupAutoUpdate do={
  :global AutoUpdateInterval;
  :if ([:typeof $AutoUpdateInterval] != "str") do={ :set AutoUpdateInterval "1h"; }
  :local ExistingSched [ /system/scheduler/find where name="txmtc-auto-update" ];
  :if ([:len $ExistingSched] > 0) do={ /system/scheduler/remove $ExistingSched; }
  /system/scheduler/add name="txmtc-auto-update" interval=$AutoUpdateInterval on-event="system script run update-scripts" start-time=startup comment="TxMTC Auto-Update";
  :log info ("update-scripts - Auto-update scheduler set to " . $AutoUpdateInterval);
  :return true;
}

:global DisableAutoUpdate do={
  :local ExistingSched [ /system/scheduler/find where name="txmtc-auto-update" ];
  :if ([:len $ExistingSched] > 0) do={ /system/scheduler/remove $ExistingSched; :log info "update-scripts - Auto-update disabled"; :return true; }
  :return false;
}

# Auto-setup scheduler on first run
:if ($AutoUpdateEnabled = true) do={
  :local ExistingSched [ /system/scheduler/find where name="txmtc-auto-update" ];
  :if ([:len $ExistingSched] = 0) do={
    [$SetupAutoUpdate];
    :if ($SilentMode = false) do={ :put ("  Auto-update scheduler created (interval: " . $AutoUpdateInterval . ")"); }
  }
}
