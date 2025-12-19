#!rsc by RouterOS
# MikroTik Telegram Bot - Wireless Monitoring Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
# requires wireless interface
#
# Enhanced wireless monitoring and management
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # ============================================================================
  # LOAD MODULES
  # ============================================================================

  :global SharedFunctionsLoaded;
  :if ($SharedFunctionsLoaded != true) do={
    :onerror ModErr { /system script run "modules/shared-functions"; } do={ }
  }

  :global TelegramAPILoaded;
  :if ($TelegramAPILoaded != true) do={
    :onerror ModErr { /system script run "modules/telegram-api"; } do={ }
  }

  # ============================================================================
  # IMPORT GLOBALS
  # ============================================================================

  :global Identity;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global MonitorWirelessEnabled;
  :global MonitorWirelessAlertThreshold;

  # Imported functions
  :global SendTelegram2;

  # Initialize default settings
  :if ([:typeof $MonitorWirelessEnabled] != "bool") do={
    :set MonitorWirelessEnabled true;
  }

  :if ($MonitorWirelessEnabled != true) do={
    :log debug ($ScriptName . " - Wireless monitoring is disabled");
    :set ExitOK true;
    :error false;
  }

  # ============================================================================
  # FALLBACK FUNCTIONS
  # ============================================================================

  :if ([:typeof $SendTelegram2] != "array") do={
    :global UrlEncode;
    :if ([:typeof $UrlEncode] != "array") do={
      :set UrlEncode do={
        :local String [ :tostr $1 ]; :local Result "";
        :for I from=0 to=([:len $String] - 1) do={
          :local Char [:pick $String $I ($I + 1)];
          :if ($Char ~ "[A-Za-z0-9_.~-]") do={ :set Result ($Result . $Char); }
          :if ($Char = " ") do={ :set Result ($Result . "%20"); }
          :if ($Char = "\n") do={ :set Result ($Result . "%0A"); }
        }
        :return $Result;
      }
    }
    :set SendTelegram2 do={
      :local Notification $1;
      :global TelegramTokenId; :global TelegramChatId; :global TelegramThreadId; :global Identity; :global UrlEncode;
      :local ChatId ($Notification->"chatid"); :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
      :local ThreadId ($Notification->"threadid"); :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
      :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . ($Notification->"message"));
      :local HTTPData ("chat_id=" . $ChatId . "&disable_notification=" . ($Notification->"silent") . "&message_thread_id=" . $ThreadId . "&parse_mode=Markdown");
      :onerror SendErr { /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") http-data=($HTTPData . "&text=" . [$UrlEncode $Text]); } do={ }
    }
  }

  :log info ($ScriptName . " - Running wireless health check");

  # Check if wireless interfaces exist
  :local WirelessInterfaces;
  :onerror WIntErr {
    :set WirelessInterfaces [/interface wireless find];
  } do={
    :log debug ($ScriptName . " - No wireless support");
    :set ExitOK true;
    :error false;
  }

  :if ([:len $WirelessInterfaces] = 0) do={
    :log debug ($ScriptName . " - No wireless interfaces found");
    :set ExitOK true;
    :error false;
  }

  # ============================================================================
  # WIRELESS INTERFACE STATUS
  # ============================================================================

  :foreach WInt in=$WirelessInterfaces do={
    :local WData [/interface wireless get $WInt];
    :local WName ($WData->"name");
    :local WRunning ($WData->"running");
    :local WDisabled ($WData->"disabled");
    
    # Alert if interface is down but not disabled
    :if ($WRunning = false && $WDisabled = false) do={
      $SendTelegram2 ({ origin=$ScriptName; silent=false; \
        subject="📡 Wireless Interface Down"; \
        message=("Wireless interface " . $WName . " on " . $Identity . " is down!") });
      :log warning ($ScriptName . " - Wireless interface down: " . $WName);
    }
  }

  # ============================================================================
  # CLIENT COUNT MONITORING
  # ============================================================================

  :local TotalClients 0;
  :local ClientDetails "";
  
  :foreach WInt in=$WirelessInterfaces do={
    :local WName [/interface wireless get $WInt name];
    
    :onerror RegErr {
      :local RegTable [/interface wireless registration-table find where interface=$WName];
      :local ClientCount [:len $RegTable];
      :set TotalClients ($TotalClients + $ClientCount);
      
      :if ($ClientCount > 0) do={
        :set ClientDetails ($ClientDetails . "\n*" . $WName . ":* " . $ClientCount . " client(s)");
        
        :foreach Client in=$RegTable do={
          :local CData [/interface wireless registration-table get $Client];
          :local MAC ($CData->"mac-address");
          :local Signal ($CData->"signal-strength");
          :set ClientDetails ($ClientDetails . "\n  • " . $MAC . " (" . $Signal . ")");
        }
      }
    } do={ }
  }

  # Alert on threshold
  :if ([:typeof $MonitorWirelessAlertThreshold] = "num" && $TotalClients > $MonitorWirelessAlertThreshold) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="📡 High Wireless Client Count"; \
      message=("Wireless client count on " . $Identity . " is high!\n\n" . \
        "Total clients: " . $TotalClients . "\nThreshold: " . $MonitorWirelessAlertThreshold . $ClientDetails) });
    :log warning ($ScriptName . " - High wireless client count: " . $TotalClients);
  }

  # ============================================================================
  # SIGNAL STRENGTH MONITORING
  # ============================================================================

  :foreach WInt in=$WirelessInterfaces do={
    :local WName [/interface wireless get $WInt name];
    
    :onerror RegErr {
      :local RegTable [/interface wireless registration-table find where interface=$WName];
      
      :foreach Client in=$RegTable do={
        :local CData [/interface wireless registration-table get $Client];
        :local MAC ($CData->"mac-address");
        :local SignalStr ($CData->"signal-strength");
        # Parse signal value
        :local Signal [:tonum [:pick $SignalStr 0 [:find $SignalStr "dBm"]]];
        
        # Alert on weak signal (< -80 dBm)
        :if ([:typeof $Signal] = "num" && $Signal < -80) do={
          $SendTelegram2 ({ origin=$ScriptName; silent=true; \
            subject="📶 Weak Wireless Signal"; \
            message=("Client with weak signal on " . $Identity . "\n\n" . \
              "Interface: " . $WName . "\nMAC: " . $MAC . "\nSignal: " . $SignalStr) });
          :log info ($ScriptName . " - Weak signal: " . $MAC . " on " . $WName);
        }
      }
    } do={ }
  }

  # ============================================================================
  # COMMAND HANDLERS
  # ============================================================================

  # /wireless - Show wireless status
  :global CommandWireless do={
    :local WirelessMsg ("📡 *Wireless Status*\n\n");
    :local InterfaceCount 0;
    :local TotalClients 0;
    
    :local WirelessInterfaces;
    :onerror WIntErr {
      :set WirelessInterfaces [/interface wireless find];
    } do={ :return "No wireless support on this device"; }
    
    :if ([:len $WirelessInterfaces] = 0) do={
      :return "No wireless interfaces found";
    }
    
    :foreach WInt in=$WirelessInterfaces do={
      :local WData [/interface wireless get $WInt];
      :local WName ($WData->"name");
      :local WDisabled ($WData->"disabled");
      
      :if ($WDisabled = false) do={
        :set InterfaceCount ($InterfaceCount + 1);
        :local Status "❌";
        :if (($WData->"running") = true) do={ :set Status "✅"; }
        :set WirelessMsg ($WirelessMsg . $Status . " *" . $WName . "*\n");
        
        :set WirelessMsg ($WirelessMsg . "   SSID: `" . ($WData->"ssid") . "`\n");
        :set WirelessMsg ($WirelessMsg . "   Band: " . ($WData->"band") . "\n");
        :set WirelessMsg ($WirelessMsg . "   Frequency: " . ($WData->"frequency") . "\n");
        
        :onerror RegErr {
          :local RegTable [/interface wireless registration-table find where interface=$WName];
          :local ClientCount [:len $RegTable];
          :set TotalClients ($TotalClients + $ClientCount);
          :set WirelessMsg ($WirelessMsg . "   Clients: " . $ClientCount . "\n");
          
          :foreach Client in=$RegTable do={
            :local CData [/interface wireless registration-table get $Client];
            :set WirelessMsg ($WirelessMsg . "      • " . ($CData->"mac-address") . " (" . ($CData->"signal-strength") . ")\n");
          }
        } do={ :set WirelessMsg ($WirelessMsg . "   Clients: 0\n"); }
        :set WirelessMsg ($WirelessMsg . "\n");
      }
    }
    
    :set WirelessMsg ($WirelessMsg . "*Summary:*\n");
    :set WirelessMsg ($WirelessMsg . "Interfaces: " . $InterfaceCount . "\n");
    :set WirelessMsg ($WirelessMsg . "Total Clients: " . $TotalClients);
    
    :return $WirelessMsg;
  }

  # /wireless-scan - Scan for networks
  :global CommandWirelessScan do={
    :local Interface [:tostr $1];
    
    :if ([:len $Interface] = 0) do={
      :local WInt [/interface wireless find];
      :if ([:len $WInt] > 0) do={
        :set Interface [/interface wireless get ($WInt->0) name];
      } else={
        :return "No wireless interfaces found";
      }
    }
    
    :local ScanMsg ("🔍 *Wireless Scan: " . $Interface . "*\n\nScanning...\n\n");
    
    :onerror ScanErr {
      :local ScanResults [/interface wireless scan $Interface as-value duration=5];
      :local Count 0;
      
      :foreach Result in=$ScanResults do={
        :set Count ($Count + 1);
        :set ScanMsg ($ScanMsg . "*" . ($Result->"ssid") . "*\n");
        :set ScanMsg ($ScanMsg . "  Channel: " . ($Result->"channel") . "\n");
        :set ScanMsg ($ScanMsg . "  Signal: " . ($Result->"signal-strength") . "\n\n");
        
        :if ($Count >= 10) do={
          :set ScanMsg ($ScanMsg . "_Showing first 10 results_\n");
          :return $ScanMsg;
        }
      }
      
      :if ($Count = 0) do={ :return "No networks found"; }
      :return $ScanMsg;
    } do={
      :return ("Scan failed: " . $ScanErr);
    }
  }

  :log info ($ScriptName . " - Wireless health check completed");
  :set ExitOK true;
  
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Wireless monitoring failed: " . $Err);
  }
}
