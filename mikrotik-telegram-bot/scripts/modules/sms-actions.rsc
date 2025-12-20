#\!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# SMS Actions Module (LTE)
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Process SMS commands on LTE routers
# Inspired by eworm-de/routeros-scripts sms-action
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
  :global ValidateSyntax;

  # Import config
  :global Identity;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableSMSActions;
  :global SMSAuthorizedNumbers;
  :global SMSActions;

  # Default config values
  :if ([:typeof ] \!= "bool") do={ :set EnableSMSActions false; }
  :if ([:typeof ] \!= "array") do={ :set SMSAuthorizedNumbers ({}); }
  :if ([:typeof ] \!= "array") do={
    :set SMSActions ({
      "status"="/system script run bot-core";
      "reboot"="/system reboot";
      "backup"="/system backup save name=sms-backup"
    });
  }

  :if ( \!= true) do={
    :log debug "sms-actions - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # ═══════════════════════════════════════════════════════════════
  # SMS ACTION HANDLER (called from SMS hook)
  # ═══════════════════════════════════════════════════════════════

  :global HandleSMSAction do={
    :local Phone ;
    :local Message ;

    :global Identity;
    :global TelegramChatId;
    :global TelegramThreadId;
    :global SMSAuthorizedNumbers;
    :global SMSActions;
    :global SendTelegram2;
    :global ValidateSyntax;

    # Verify sender is authorized
    :local Authorized false;
    :foreach AuthNum in= do={
      :if ([:find  ] >= 0) do={
        :set Authorized true;
      }
    }

    :if ( \!= true) do={
      :log warning ("sms-actions - Unauthorized SMS from: " . );
       ({
        chatid=;
        threadid=;
        silent=false;
        subject=("[" .  . "] Unauthorized SMS");
        message=("From: " .  . "\nMessage: " . )
      });
      :return "Unauthorized";
    }

    # Parse action
    :local Action ;
    # Trim and lowercase (manual since no tolower)
    :while ([:len ] > 0 && [:pick  0 1] = " ") do={
      :set Action [:pick  1 [:len ]];
    }
    :while ([:len ] > 0 && [:pick  ([:len ] - 1) [:len ]] = " ") do={
      :set Action [:pick  0 ([:len ] - 1)];
    }

    # Find action in registry
    :local Code (->);
    :if ([:len ] = 0) do={
      :log info ("sms-actions - Unknown action: " . );
      :return "Unknown action";
    }

    # Validate syntax
    :if ([ ] \!= true) do={
      :log error ("sms-actions - Invalid code for action: " . );
      :return "Invalid code";
    }

    # Execute action
    :log info ("sms-actions - Executing: " .  . " from " . );
     ({
      chatid=;
      threadid=;
      silent=false;
      subject=("[" .  . "] SMS Action");
      message=("Executing: " .  . "\nFrom: " . )
    });

    :onerror ExecErr {
      :local Parsed [:parse ];
      ;
      :return "OK";
    } do={
      :log error ("sms-actions - Execution failed: " . );
      :return ("Error: " . );
    }
  }

  # ═══════════════════════════════════════════════════════════════
  # PROCESS INBOX (manual check)
  # ═══════════════════════════════════════════════════════════════

  :global ProcessSMSInbox do={
    :global HandleSMSAction;

    :foreach SMS in=[/tool/sms/inbox find] do={
      :local Phone [/tool/sms/inbox get  phone];
      :local Message [/tool/sms/inbox get  message];
      :local Timestamp [/tool/sms/inbox get  timestamp];

      :log info ("sms-actions - Processing SMS from: " . );
      :local Result [  ];

      # Remove processed SMS
      /tool/sms/inbox remove ;
    }
  }

  :set ExitOK true;
} do={
  :if ( = false) do={
    :log error ([:jobname] . " - Script failed: " . );
  }
}

:global SMSActionsLoaded true;
:log info "SMS actions module loaded"
