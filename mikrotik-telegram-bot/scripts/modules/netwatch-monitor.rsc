#\!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# Netwatch Monitor Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Network host/service monitoring with Telegram alerts
# Inspired by eworm-de/routeros-scripts netwatch-notify
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if (\ \!= true) do={ :error "Config not loaded"; }; } delay=500ms max=50;

  :local ScriptName [:jobname];

  # Load dependencies
  :global SharedFunctionsLoaded;
  :if (\ \!= true) do={
    :onerror e { /system script run "modules/shared-functions"; } do={}
  }
  :global TelegramAPILoaded;
  :if (\ \!= true) do={
    :onerror e { /system script run "modules/telegram-api"; } do={}
  }

  # Import functions
  :global SendTelegram2;
  :global SaveBotState;
  :global LoadBotState;
  :global FormatDuration;

  # Import config
  :global Identity;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableNetwatchMonitor;
  :global NetwatchDownThreshold;
  :global NetwatchAlertRepeat;

  # Default config values
  :if ([:typeof \] \!= "bool") do={ :set EnableNetwatchMonitor true; }
  :if ([:typeof \] \!= "num") do={ :set NetwatchDownThreshold 3; }
  :if ([:typeof \] \!= "num") do={ :set NetwatchAlertRepeat 60; }

  :if (\ \!= true) do={
    :log debug "netwatch-monitor - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # Load state
  :global NetwatchState;
  :if ([:typeof \] \!= "array") do={
    :local Loaded [\ "netwatch"];
    :if ([:typeof \] = "array" && [:len \] > 0) do={
      :set NetwatchState \;
    } else={
      :set NetwatchState ({});
    }
  }

  # ═══════════════════════════════════════════════════════════════
  # PROCESS NETWATCH ENTRIES
  # ═══════════════════════════════════════════════════════════════

  :foreach Entry in=[/tool/netwatch find where comment~"notify"] do={
    :local Host [/tool/netwatch get \ host];
    :local Status [/tool/netwatch get \ status];
    :local Comment [/tool/netwatch get \ comment];
    :local Since [/tool/netwatch get \ since];

    # Get or create state for this host
    :local HostKey [:tostr \];
    :local State (\->\);
    :if ([:typeof \] \!= "array") do={
      :set State ({
        "downCount"=0;
        "upCount"=0;
        "notified"=false;
        "lastStatus"="unknown";
        "downSince"=""
      });
    }

    :local DownCount (\->"downCount");
    :local UpCount (\->"upCount");
    :local Notified (\->"notified");
    :local LastStatus (\->"lastStatus");
    :local DownSince (\->"downSince");

    :if (\ = "down") do={
      :set DownCount (\ + 1);
      :set UpCount 0;
      
      :if (\ = "") do={
        :set DownSince [:tostr [/system clock get time]];
      }

      # Alert if threshold reached and not notified
      :if (\ >= \ && \ \!= true) do={
        :log warning ("netwatch-monitor - Host DOWN: " . \);
        
        \ ({
          chatid=\;
          threadid=\;
          silent=false;
          subject=("[" . \ . "] Host DOWN");
          message=("Host: " . \ . "
Status: DOWN
Down for: " . \ . " checks
Comment: " . \)
        });
        
        :set Notified true;
      }

      # Repeat alert every N checks
      :if (\ = true && (\ % \) = 0) do={
        :log info ("netwatch-monitor - Host still DOWN: " . \);
        
        \ ({
          chatid=\;
          threadid=\;
          silent=true;
          subject=("[" . \ . "] Host still DOWN");
          message=("Host: " . \ . "
Status: Still DOWN
Down for: " . \ . " checks")
        });
      }

    } else={
      # Host is UP
      :set UpCount (\ + 1);

      # If was notified as down, send recovery
      :if (\ = true && \ >= 2) do={
        :log info ("netwatch-monitor - Host UP: " . \);
        
        :local Downtime "unknown";
        :if (\ \!= "") do={
          :set Downtime ("Was down for " . [:tostr \] . " checks");
        }

        \ ({
          chatid=\;
          threadid=\;
          silent=false;
          subject=("[" . \ . "] Host UP");
          message=("Host: " . \ . "
Status: RECOVERED
" . \)
        });

        :set Notified false;
        :set DownCount 0;
        :set DownSince "";
      }
    }

    # Update state
    :set (\->"downCount") \;
    :set (\->"upCount") \;
    :set (\->"notified") \;
    :set (\->"lastStatus") \;
    :set (\->"downSince") \;
    :set (\->\) \;
  }

  # Save state
  \ "netwatch" \;

  :set ExitOK true;
} do={
  :if (\ = false) do={
    :log error ([:jobname] . " - Script failed: " . \);
  }
}

:global NetwatchMonitorLoaded true;
:log info "Netwatch monitor module loaded"
