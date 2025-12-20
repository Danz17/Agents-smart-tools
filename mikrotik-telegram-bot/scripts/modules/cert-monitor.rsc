#\!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# Certificate Monitor Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Monitor SSL certificate expiration
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

  # Import config
  :global Identity;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableCertMonitor;
  :global CertExpiryDays;

  # Default config values
  :if ([:typeof ] \!= "bool") do={ :set EnableCertMonitor true; }
  :if ([:typeof ] \!= "num") do={ :set CertExpiryDays 30; }

  :if ( \!= true) do={
    :log debug "cert-monitor - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # ═══════════════════════════════════════════════════════════════
  # LOAD STATE
  # ═══════════════════════════════════════════════════════════════

  :global CertMonitorState;
  :if ([:typeof ] \!= "array") do={
    :local Loaded [ "cert-monitor"];
    :if ([:typeof ] = "array") do={
      :set CertMonitorState ;
    } else={
      :set CertMonitorState ({});
    }
  }

  # ═══════════════════════════════════════════════════════════════
  # CHECK CERTIFICATES
  # ═══════════════════════════════════════════════════════════════

  :local Now [/system clock get date];
  :local WarningCount 0;

  :foreach Cert in=[/certificate find] do={
    :local Name [/certificate get  name];
    :local CommonName [/certificate get  common-name];
    :local InvalidAfter [/certificate get  invalid-after];
    :local Trusted [/certificate get  trusted];

    # Skip CA certificates
    :if ( = true) do={
      :log debug ("cert-monitor - Skipping trusted CA: " . );
    } else={
      # Check if certificate has expiry date
      :if ([:len ] > 0) do={
        # Calculate days until expiry (simplified)
        # Format: mon/dd/yyyy HH:MM:SS
        :local ExpiryDate [:pick  0 [:find  " "]];

        # Check if we already notified for this cert
        :local LastNotified (->);
        :local Today [:pick  0 10];

        :if ( \!= ) do={
          # Parse expiry - this is simplified, may need adjustment
          :log info ("cert-monitor - Checking: " .  . " expires: " . );

          # For now, just send a summary
          :set WarningCount ( + 1);

           ({
            chatid=;
            threadid=;
            silent=true;
            subject=("[" .  . "] Certificate Expiry Warning");
            message=("Certificate: " .  . "\nCommon Name: " .  . "\nExpires: " .  . "\n\nPlease renew before expiry.")
          });

          :set (->) ;
        }
      }
    }
  }

  :if ( > 0) do={
     "cert-monitor" ;
    :log info ("cert-monitor - Sent " .  . " expiry warnings");
  }

  :set ExitOK true;
} do={
  :if ( = false) do={
    :log error ([:jobname] . " - Script failed: " . );
  }
}

:global CertMonitorLoaded true;
:log info "Certificate monitor module loaded"
