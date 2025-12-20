#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# Log Monitor Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Forward important log entries to Telegram
# Inspired by eworm-de/routeros-scripts log-forward
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ( != true) do={ :error "Config not loaded"; }; } delay=500ms max=50;

  :local ScriptName [:jobname];

  # Load dependencies
  :global SharedFunctionsLoaded;
  :if ( != true) do={
    :onerror e { /system script run "modules/shared-functions"; } do={}
  }
  :global TelegramAPILoaded;
  :if ( != true) do={
    :onerror e { /system script run "modules/telegram-api"; } do={}
  }

  # Import functions
  :global SendTelegram2;
  :global SaveBotState;
  :global LoadBotState;

  # Import config
  :global Identity;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableLogMonitor;
  :global LogMonitorTopics;
  :global LogMonitorExclude;
  :global LogMonitorMaxPerMinute;

  # Default config values
  :if ([:typeof ] != "bool") do={ :set EnableLogMonitor true; }
  :if ([:typeof ] != "str") do={ :set LogMonitorTopics "critical,error,warning"; }
  :if ([:typeof ] != "str") do={ :set LogMonitorExclude ""; }
  :if ([:typeof ] != "num") do={ :set LogMonitorMaxPerMinute 10; }

  :if ( != true) do={
    :log debug "log-monitor - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # ═══════════════════════════════════════════════════════════════
  # LOAD STATE
  # ═══════════════════════════════════════════════════════════════

  :global LogMonitorState;
  :if ([:typeof ] != "array") do={
    :local Loaded [ "log-monitor"];
    :if ([:typeof ] = "array") do={
      :set LogMonitorState ;
    } else={
      :set LogMonitorState ({"lastId"=0; "sentCount"=0; "lastReset"=""});
    }
  }

  :local LastId (->"lastId");
  :local SentCount (->"sentCount");

  # Reset counter every minute
  :local CurrentMinute [:pick [:tostr [/system clock get time]] 3 5];
  :local LastReset (->"lastReset");
  :if ( != ) do={
    :set SentCount 0;
    :set (->"lastReset") ;
  }

  # ═══════════════════════════════════════════════════════════════
  # PROCESS LOG ENTRIES
  # ═══════════════════════════════════════════════════════════════

  :local NewLastId ;
  :local Topics [:toarray ];
  :local MessageCount 0;
  :local Messages "";

  :foreach LogEntry in=[/log find] do={
    :local Id [:tostr ];
    :local IdNum 0;
    :onerror e { :set IdNum [:tonum [:pick  1 [:len ]]]; } do={}

    :if ( > ) do={
      :local LogTime [/log get  time];
      :local LogTopics [/log get  topics];
      :local LogMessage [/log get  message];

      # Check if topic matches
      :local Match false;
      :foreach Topic in= do={
        :if ([:find  ] >= 0) do={
          :set Match true;
        }
      }

      # Check exclusions
      :if ( = true && [:len ] > 0) do={
        :if ([:find  ] >= 0) do={
          :set Match false;
        }
      }

      :if ( = true &&  < ) do={
        :set Messages ( .  . " [" .  . "] " .  . "\n");
        :set MessageCount ( + 1);
        :set SentCount ( + 1);
      }

      :if ( > ) do={
        :set NewLastId ;
      }
    }
  }

  # Send notification if we have messages
  :if ( > 0) do={
    :log info ("log-monitor - Forwarding " .  . " log entries");

     ({
      chatid=;
      threadid=;
      silent=true;
      subject=("[" .  . "] Log Alert");
      message=
    });
  }

  # Update state
  :set (->"lastId") ;
  :set (->"sentCount") ;
   "log-monitor" ;

  :set ExitOK true;
} do={
  :if ( = false) do={
    :log error ([:jobname] . " - Script failed: " . );
  }
}

:global LogMonitorLoaded true;
:log info "Log monitor module loaded"
