#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Auto-Updater Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Checks for script updates and manages version upgrades
# Dependencies: shared-functions, telegram-api, script-registry

# ============================================================================
# LOADING GUARD
# ============================================================================

:global AutoUpdaterLoaded;
:if ($AutoUpdaterLoaded = true) do={
  :return;
}

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error ("[auto-updater] - Failed to load shared-functions: " . $LoadErr);
    :return;
  }
}

:global ScriptRegistryLoaded;
:if ($ScriptRegistryLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/script-registry";
  } do={
    :log warning "[auto-updater] - Script registry not available";
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global CompareVersions;
:global GetScriptInfo;
:global InstallScriptFromRegistry;
:global TelegramChatId;

# ============================================================================
# CONFIGURATION
# ============================================================================

:global AutoUpdateEnabled;
:global AutoUpdateInterval;
:global AutoUpdateNotify;
:global AutoInstallMinor;
:global LastUpdateCheck;

:if ([:typeof $AutoUpdateEnabled] != "bool") do={ :set AutoUpdateEnabled false; }
:if ([:typeof $AutoUpdateInterval] != "time") do={ :set AutoUpdateInterval 1d; }
:if ([:typeof $AutoUpdateNotify] != "bool") do={ :set AutoUpdateNotify true; }
:if ([:typeof $AutoInstallMinor] != "bool") do={ :set AutoInstallMinor false; }
:if ([:typeof $LastUpdateCheck] != "time") do={ :set LastUpdateCheck 0s; }

# Current version of the bot system
:global TxMTCVersion "2.1.0";

# GitHub raw base URL for direct file fetching
:global GitHubRawBase "https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot";

# ============================================================================
# GITHUB MODULE LIST (modules to sync from GitHub)
# ============================================================================

:global GitHubModules ({
  "interactive-menu"="scripts/modules/interactive-menu.rsc";
  "shared-functions"="scripts/modules/shared-functions.rsc";
  "telegram-api"="scripts/modules/telegram-api.rsc";
  "bot-core"="scripts/bot-core.rsc";
  "monitoring"="scripts/modules/monitoring.rsc";
  "script-registry"="scripts/modules/script-registry.rsc";
  "auto-updater"="scripts/modules/auto-updater.rsc"
});

# ============================================================================
# PULL MODULE FROM GITHUB
# ============================================================================

:global PullModuleFromGitHub do={
  :local ModuleName [:tostr $1];
  :global GitHubRawBase;
  :global GitHubModules;
  :global CertificateAvailable;

  :local ModulePath ($GitHubModules->$ModuleName);
  :if ([:len $ModulePath] = 0) do={
    :return ({success=false; error="Module not in sync list"});
  }

  :local Url ($GitHubRawBase . "/" . $ModulePath);
  :local LocalPath [:pick $ModulePath ([:find $ModulePath "/"] + 1) [:len $ModulePath]];

  :log info ("[auto-updater] - Pulling " . $ModuleName . " from GitHub");

  :onerror FetchErr {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no url=$Url dst-path=$LocalPath;
    } else={
      /tool/fetch check-certificate=yes-without-crl url=$Url dst-path=$LocalPath;
    }

    # Reimport the module
    :onerror ImportErr {
      /import $LocalPath;
    } do={
      :log warning ("[auto-updater] - Import failed for " . $ModuleName . ": " . $ImportErr);
    }

    :log info ("[auto-updater] - Updated " . $ModuleName);
    :return ({success=true; module=$ModuleName});
  } do={
    :log error ("[auto-updater] - Failed to fetch " . $ModuleName . ": " . $FetchErr);
    :return ({success=false; error=$FetchErr});
  }
}

# ============================================================================
# PULL ALL MODULES FROM GITHUB
# ============================================================================

:global PullAllFromGitHub do={
  :global GitHubModules;
  :global PullModuleFromGitHub;
  :global SendTelegram2;
  :global TelegramChatId;

  :local SuccessCount 0;
  :local FailCount 0;
  :local Results ({});

  :foreach ModuleName,Path in=$GitHubModules do={
    :local Result [$PullModuleFromGitHub $ModuleName];
    :if (($Result->"success") = true) do={
      :set SuccessCount ($SuccessCount + 1);
    } else={
      :set FailCount ($FailCount + 1);
    }
    :set ($Results->$ModuleName) $Result;
  }

  :local Msg ("🔄 GitHub Sync: " . $SuccessCount . " updated");
  :if ($FailCount > 0) do={
    :set Msg ($Msg . ", " . $FailCount . " failed");
  }

  $SendTelegram2 ({
    chatid=$TelegramChatId;
    silent=true;
    subject="🔄 TxMTC GitHub Sync";
    message=$Msg
  });

  :log info ("[auto-updater] - GitHub sync complete: " . $SuccessCount . " success, " . $FailCount . " failed");
  :return ({success=($FailCount = 0); updated=$SuccessCount; failed=$FailCount; details=$Results});
}

# ============================================================================
# START GITHUB SYNC SCHEDULER
# ============================================================================

:global StartGitHubSync do={
  :local Interval $1;
  :if ([:typeof $Interval] != "time") do={ :set Interval 1h; }

  # Remove existing scheduler if present
  :onerror Err {
    /system scheduler remove [find name="txmtc-github-sync"];
  } do={}

  # Create new scheduler
  /system scheduler add \
    name="txmtc-github-sync" \
    interval=$Interval \
    on-event=":global PullAllFromGitHub; [\$PullAllFromGitHub]" \
    comment="TxMTC GitHub Auto-Sync";

  :log info ("[auto-updater] - GitHub sync scheduler started (interval: " . $Interval . ")");
}

# ============================================================================
# STOP GITHUB SYNC SCHEDULER
# ============================================================================

:global StopGitHubSync do={
  :onerror Err {
    /system scheduler remove [find name="txmtc-github-sync"];
  } do={}

  :log info "[auto-updater] - GitHub sync scheduler stopped";
}

# ============================================================================
# GET INSTALLED SCRIPTS WITH VERSIONS
# ============================================================================

:global GetInstalledScripts do={
  :local Installed ({});

  :onerror Err {
    :foreach Script in=[/system script find] do={
      :local ScriptName [/system script get $Script name];
      :local ScriptSource [/system script get $Script source];

      # Extract version from script header
      :local Version "";
      :local VerPos [:find $ScriptSource "version="];
      :if ([:typeof $VerPos] = "num") do={
        :local VerStart ($VerPos + 8);
        :local VerEnd [:find $ScriptSource "\n" $VerStart];
        :if ([:typeof $VerEnd] = "num") do={
          :set Version [:pick $ScriptSource $VerStart $VerEnd];
          :set Version [:pick $Version 0 [:find $Version " "]];
          :if ([:typeof [:find $Version " "]] != "num") do={
            :set Version [:pick $Version 0 [:len $Version]];
          }
        }
      }

      :if ([:len $Version] > 0) do={
        :set ($Installed->$ScriptName) $Version;
      }
    }
  } do={
    :log warning ("[auto-updater] - Error scanning scripts: " . $Err);
  }

  :return $Installed;
}

# ============================================================================
# CHECK FOR UPDATES
# ============================================================================

:global CheckForUpdates do={
  :global GetInstalledScripts;
  :global GetScriptInfo;
  :global CompareVersions;
  :global TxMTCVersion;

  :local Installed [$GetInstalledScripts];
  :local Updates ({});
  :local UpdateCount 0;

  # Check each installed script against registry
  :foreach ScriptName,InstalledVer in=$Installed do={
    :local RegistryInfo [$GetScriptInfo $ScriptName];
    :if ([:typeof $RegistryInfo] = "array") do={
      :local RegistryVer ($RegistryInfo->"version");
      :if ([:len $RegistryVer] > 0) do={
        :local Comparison [$CompareVersions $RegistryVer $InstalledVer];
        :if ($Comparison > 0) do={
          :set ($Updates->$ScriptName) ({
            "current"=$InstalledVer;
            "available"=$RegistryVer;
            "name"=($RegistryInfo->"name");
            "type"=($RegistryInfo->"type")
          });
          :set UpdateCount ($UpdateCount + 1);
        }
      }
    }
  }

  :return ({
    "count"=$UpdateCount;
    "updates"=$Updates
  });
}

# ============================================================================
# FORMAT UPDATE NOTIFICATION
# ============================================================================

:global FormatUpdateNotification do={
  :local Updates $1;
  :local Count ($Updates->"count");

  :if ($Count = 0) do={
    :return "✅ All scripts are up to date!";
  }

  :local Msg ("🔄 *Updates Available* (" . $Count . ")\n\n");

  :foreach ScriptId,Info in=($Updates->"updates") do={
    :local Name ($Info->"name");
    :local Current ($Info->"current");
    :local Available ($Info->"available");
    :set Msg ($Msg . "📦 *" . $Name . "*\n");
    :set Msg ($Msg . "   `" . $Current . "` → `" . $Available . "`\n\n");
  }

  :set Msg ($Msg . "_Use `/update install <name>` to update_");
  :return $Msg;
}

# ============================================================================
# INSTALL UPDATE
# ============================================================================

:global InstallUpdate do={
  :local ScriptId [:tostr $1];
  :global InstallScriptFromRegistry;
  :global GetScriptInfo;

  :local Info [$GetScriptInfo $ScriptId];
  :if ([:typeof $Info] != "array") do={
    :return ({success=false; error="Script not found in registry"});
  }

  :local Result [$InstallScriptFromRegistry $ScriptId];
  :return $Result;
}

# ============================================================================
# INSTALL ALL UPDATES
# ============================================================================

:global InstallAllUpdates do={
  :global CheckForUpdates;
  :global InstallUpdate;

  :local Updates [$CheckForUpdates];
  :local Results ({});
  :local SuccessCount 0;
  :local FailCount 0;

  :foreach ScriptId,Info in=($Updates->"updates") do={
    :local Result [$InstallUpdate $ScriptId];
    :if (($Result->"success") = true) do={
      :set SuccessCount ($SuccessCount + 1);
    } else={
      :set FailCount ($FailCount + 1);
    }
    :set ($Results->$ScriptId) $Result;
  }

  :return ({
    success=($FailCount = 0);
    updated=$SuccessCount;
    failed=$FailCount;
    details=$Results
  });
}

# ============================================================================
# RUN UPDATE CHECK (Scheduled)
# ============================================================================

:global RunUpdateCheck do={
  :global CheckForUpdates;
  :global FormatUpdateNotification;
  :global SendTelegram2;
  :global TelegramChatId;
  :global AutoUpdateNotify;
  :global AutoInstallMinor;
  :global LastUpdateCheck;

  :set LastUpdateCheck [/system clock get time];

  :local Updates [$CheckForUpdates];

  :if (($Updates->"count") > 0) do={
    :if ($AutoInstallMinor = true) do={
      # Auto-install minor updates
      :global InstallAllUpdates;
      :local Result [$InstallAllUpdates];

      :local Msg "";
      :if (($Result->"success") = true) do={
        :set Msg ("✅ Auto-updated " . ($Result->"updated") . " scripts");
      } else={
        :set Msg ("⚠️ Updated " . ($Result->"updated") . ", failed " . ($Result->"failed"));
      }

      :if ($AutoUpdateNotify = true) do={
        $SendTelegram2 ({
          chatid=$TelegramChatId;
          silent=true;
          subject="🔄 TxMTC Auto-Update";
          message=$Msg
        });
      }
    } else={
      # Just notify about available updates
      :if ($AutoUpdateNotify = true) do={
        :local Msg [$FormatUpdateNotification $Updates];
        $SendTelegram2 ({
          chatid=$TelegramChatId;
          silent=true;
          subject="🔄 TxMTC Updates";
          message=$Msg
        });
      }
    }
  }

  :log info ("[auto-updater] - Check complete: " . ($Updates->"count") . " updates available");
}

# ============================================================================
# START AUTO-UPDATER SCHEDULER
# ============================================================================

:global StartAutoUpdater do={
  :global AutoUpdateInterval;
  :global AutoUpdateEnabled;

  :set AutoUpdateEnabled true;

  # Remove existing scheduler if present
  :onerror Err {
    /system scheduler remove [find name="txmtc-auto-updater"];
  } do={}

  # Create new scheduler
  /system scheduler add \
    name="txmtc-auto-updater" \
    interval=$AutoUpdateInterval \
    on-event=":global RunUpdateCheck; [\$RunUpdateCheck]" \
    comment="TxMTC Auto-Update Checker";

  :log info "[auto-updater] - Auto-updater started";
}

# ============================================================================
# STOP AUTO-UPDATER SCHEDULER
# ============================================================================

:global StopAutoUpdater do={
  :global AutoUpdateEnabled;

  :set AutoUpdateEnabled false;

  :onerror Err {
    /system scheduler remove [find name="txmtc-auto-updater"];
  } do={}

  :log info "[auto-updater] - Auto-updater stopped";
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:set AutoUpdaterLoaded true;
:log info "Auto-updater module loaded"
