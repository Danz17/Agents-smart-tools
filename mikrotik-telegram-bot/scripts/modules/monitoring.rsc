#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Monitoring Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# System monitoring with automatic alerts
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
  :global EnableAutoMonitoring;
  :global MonitorCPUThreshold;
  :global MonitorRAMThreshold;
  :global MonitorDiskThreshold;
  :global MonitorTempThreshold;
  :global MonitorVoltageMin;
  :global MonitorVoltageMax;
  :global MonitorInterfaces;
  :global CheckHealthCPUUtilization;
  :global CheckHealthCPUUtilizationNotified;
  :global CheckHealthRAMUtilizationNotified;
  :global CheckHealthDiskUtilizationNotified;
  :global CheckHealthInternetConnectivity;
  :global CheckHealthInterfaceDown;
  :global TelegramChatId;
  :global TelegramThreadId;

  # Imported functions
  :global SendTelegram2;
  :global FormatNumber;
  :global ParseCSV;

  # Check if monitoring is enabled
  :if ($EnableAutoMonitoring != true) do={
    :log debug ($ScriptName . " - Monitoring is disabled");
    :set ExitOK true;
    :error false;
  }

  # ============================================================================
  # FALLBACK FUNCTIONS (if modules not loaded)
  # ============================================================================

  :if ([:typeof $SendTelegram2] != "array") do={
    :global UrlEncode;
    :if ([:typeof $UrlEncode] != "array") do={
      :set UrlEncode do={
        :local String [ :tostr $1 ];
        :local Result "";
        :for I from=0 to=([:len $String] - 1) do={
          :local Char [:pick $String $I ($I + 1)];
          :if ($Char ~ "[A-Za-z0-9_.~-]") do={ :set Result ($Result . $Char); }
          :if ($Char = " ") do={ :set Result ($Result . "%20"); }
          :if ($Char = "\n") do={ :set Result ($Result . "%0A"); }
        }
        :return $Result;
      }
    }
    :global TelegramTokenId;
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

  :if ([:typeof $FormatNumber] != "array") do={
    :set FormatNumber do={
      :local Num [:tonum $1]; :local Div [:tonum $2]; :local Units ({""; "K"; "M"; "G"; "T"}); :local UnitIndex 0;
      :if ([:typeof $Div] != "num" || $Div = 0) do={ :set Div 1024; }
      :while ($Num >= $Div && $UnitIndex < 4) do={ :set Num ($Num / $Div); :set UnitIndex ($UnitIndex + 1); }
      :return ([:tostr $Num] . ($Units->$UnitIndex));
    }
  }

  :log info ($ScriptName . " - Running system health check");

  # ============================================================================
  # CPU MONITORING
  # ============================================================================
  
  :local Resource [ /system/resource/get ];
  :local CurrentCPU (($Resource->"cpu-load") * 10);
  
  :if ([:typeof $CheckHealthCPUUtilization] != "num") do={
    :set CheckHealthCPUUtilization $CurrentCPU;
  }
  
  # 5-point moving average
  :set CheckHealthCPUUtilization (($CheckHealthCPUUtilization * 4 + $CurrentCPU) / 5);
  
  :if ($CheckHealthCPUUtilization > ($MonitorCPUThreshold * 10) && $CheckHealthCPUUtilizationNotified != true) do={
    $SendTelegram2 ({ silent=false; \
      subject="⚠️ CPU Utilization Alert"; \
      message=("CPU utilization on " . $Identity . " is high!\n\n" . \
        "Average: " . ($CheckHealthCPUUtilization / 10) . "%\n" . \
        "Threshold: " . $MonitorCPUThreshold . "%\n" . \
        "Current: " . ($Resource->"cpu-load") . "%") });
    :set CheckHealthCPUUtilizationNotified true;
    :log warning ($ScriptName . " - CPU utilization high: " . ($CheckHealthCPUUtilization / 10) . "%");
  }
  
  :if ($CheckHealthCPUUtilization < (($MonitorCPUThreshold - 10) * 10) && $CheckHealthCPUUtilizationNotified = true) do={
    $SendTelegram2 ({ silent=true; \
      subject="✅ CPU Utilization Recovered"; \
      message=("CPU utilization on " . $Identity . " returned to normal.\n\nAverage: " . ($CheckHealthCPUUtilization / 10) . "%") });
    :set CheckHealthCPUUtilizationNotified false;
    :log info ($ScriptName . " - CPU utilization normal: " . ($CheckHealthCPUUtilization / 10) . "%");
  }

  # ============================================================================
  # RAM MONITORING
  # ============================================================================
  
  :local TotalRAM ($Resource->"total-memory");
  :local FreeRAM ($Resource->"free-memory");
  :local UsedRAM ($TotalRAM - $FreeRAM);
  :local RAMPercent ($UsedRAM * 100 / $TotalRAM);
  
  :if ($RAMPercent >= $MonitorRAMThreshold && $CheckHealthRAMUtilizationNotified != true) do={
    $SendTelegram2 ({ silent=false; \
      subject="⚠️ RAM Utilization Alert"; \
      message=("RAM utilization on " . $Identity . " is high!\n\n" . \
        "Used: " . $RAMPercent . "%\n" . \
        "Total: " . [$FormatNumber $TotalRAM 1024] . "B\n" . \
        "Free: " . [$FormatNumber $FreeRAM 1024] . "B") });
    :set CheckHealthRAMUtilizationNotified true;
    :log warning ($ScriptName . " - RAM utilization high: " . $RAMPercent . "%");
  }
  
  :if ($RAMPercent < ($MonitorRAMThreshold - 10) && $CheckHealthRAMUtilizationNotified = true) do={
    $SendTelegram2 ({ silent=true; \
      subject="✅ RAM Utilization Recovered"; \
      message=("RAM utilization on " . $Identity . " returned to normal.\n\nUsed: " . $RAMPercent . "%") });
    :set CheckHealthRAMUtilizationNotified false;
    :log info ($ScriptName . " - RAM utilization normal: " . $RAMPercent . "%");
  }

  # ============================================================================
  # DISK MONITORING
  # ============================================================================
  
  :local TotalHDD ($Resource->"total-hdd-space");
  :local FreeHDD ($Resource->"free-hdd-space");
  :local UsedHDD ($TotalHDD - $FreeHDD);
  :local HDDPercent ($UsedHDD * 100 / $TotalHDD);
  
  :if ($HDDPercent >= $MonitorDiskThreshold && $CheckHealthDiskUtilizationNotified != true) do={
    $SendTelegram2 ({ silent=false; \
      subject="⚠️ Disk Usage Alert"; \
      message=("Disk usage on " . $Identity . " is high!\n\n" . \
        "Used: " . $HDDPercent . "%\n" . \
        "Total: " . [$FormatNumber $TotalHDD 1024] . "B\n" . \
        "Free: " . [$FormatNumber $FreeHDD 1024] . "B") });
    :set CheckHealthDiskUtilizationNotified true;
    :log warning ($ScriptName . " - Disk usage high: " . $HDDPercent . "%");
  }
  
  :if ($HDDPercent < ($MonitorDiskThreshold - 10) && $CheckHealthDiskUtilizationNotified = true) do={
    $SendTelegram2 ({ silent=true; \
      subject="✅ Disk Usage Recovered"; \
      message=("Disk usage on " . $Identity . " returned to normal.\n\nUsed: " . $HDDPercent . "%") });
    :set CheckHealthDiskUtilizationNotified false;
    :log info ($ScriptName . " - Disk usage normal: " . $HDDPercent . "%");
  }

  # ============================================================================
  # TEMPERATURE MONITORING
  # ============================================================================
  
  :onerror TempErr {
    :local TempVal [ /system/health/get value-name=temperature ];
    :if ([:typeof $TempVal] = "num" && $TempVal > $MonitorTempThreshold) do={
      $SendTelegram2 ({ silent=false; \
        subject="🌡️ Temperature Alert"; \
        message=("Temperature on " . $Identity . " is high!\n\n" . \
          "Current: " . $TempVal . "°C\nThreshold: " . $MonitorTempThreshold . "°C") });
      :log warning ($ScriptName . " - Temperature high: " . $TempVal . "°C");
    }
  } do={ :log debug ($ScriptName . " - No temperature sensor available"); }

  # ============================================================================
  # VOLTAGE MONITORING
  # ============================================================================
  
  :onerror VoltErr {
    :local VoltageVal [ /system/health/get value-name=voltage ];
    :if ([:typeof $VoltageVal] = "num" && ($VoltageVal < $MonitorVoltageMin || $VoltageVal > $MonitorVoltageMax)) do={
      $SendTelegram2 ({ silent=false; \
        subject="⚡ Voltage Alert"; \
        message=("Voltage on " . $Identity . " is out of range!\n\n" . \
          "Current: " . $VoltageVal . "V\nExpected: " . $MonitorVoltageMin . "-" . $MonitorVoltageMax . "V") });
      :log warning ($ScriptName . " - Voltage out of range: " . $VoltageVal . "V");
    }
  } do={ :log debug ($ScriptName . " - No voltage sensor available"); }

  # ============================================================================
  # INTERFACE MONITORING
  # ============================================================================
  
  :if ([:len $MonitorInterfaces] > 0) do={
    # Parse interface list
    :local InterfaceList;
    :if ([:typeof $ParseCSV] = "array") do={
      :set InterfaceList [$ParseCSV $MonitorInterfaces];
    } else={
      # Manual parsing fallback
      :set InterfaceList ({});
      :local Current "";
      :for I from=0 to=([:len $MonitorInterfaces] - 1) do={
        :local Char [:pick $MonitorInterfaces $I ($I + 1)];
        :if ($Char = ",") do={
          :if ([:len $Current] > 0) do={ :set ($InterfaceList->[:len $InterfaceList]) $Current; :set Current ""; }
        } else={ :set Current ($Current . $Char); }
      }
      :if ([:len $Current] > 0) do={ :set ($InterfaceList->[:len $InterfaceList]) $Current; }
    }
    
    # Initialize interface down tracking
    :if ([:typeof $CheckHealthInterfaceDown] != "array") do={
      :set CheckHealthInterfaceDown ({});
    }
    
    :foreach IntName in=$InterfaceList do={
      :onerror IntErr {
        :local IntFound [/interface/find where name=$IntName];
        :if ([:len $IntFound] = 0) do={
          :log debug ($ScriptName . " - Interface not found: " . $IntName);
          # Remove from tracking if interface doesn't exist
          :if ([:typeof ($CheckHealthInterfaceDown->$IntName)] != "nothing") do={
            :set ($CheckHealthInterfaceDown->$IntName) "";
          }
        } else={
          :local Int [ /interface/get $IntFound ];
          :local IsDisabled ($Int->"disabled");
          :local IsRunning ($Int->"running");
          :local WasDown ($CheckHealthInterfaceDown->$IntName);
          
          # Only alert if interface is enabled but not running (should be up but is down)
          :local IsDown ($IsDisabled = false && $IsRunning = false);
          
          # Alert if interface just went down (wasn't down before)
          :if ($IsDown = true && $WasDown != true) do={
            $SendTelegram2 ({ silent=false; \
              subject="🔌 Interface Down Alert"; \
              message=("Interface " . $IntName . " on " . $Identity . " is down!\n\nStatus: Enabled but not running.") });
            :log warning ($ScriptName . " - Interface down: " . $IntName);
            :set ($CheckHealthInterfaceDown->$IntName) true;
          }
          
          # Alert recovery if interface came back up (was down before)
          :if ($IsDown = false && $WasDown = true) do={
            $SendTelegram2 ({ silent=true; \
              subject="✅ Interface Recovered"; \
              message=("Interface " . $IntName . " on " . $Identity . " is back up.") });
            :log info ($ScriptName . " - Interface recovered: " . $IntName);
            :set ($CheckHealthInterfaceDown->$IntName) false;
          }
          
          # Update state
          :if ($IsDown = true) do={
            :set ($CheckHealthInterfaceDown->$IntName) true;
          } else={
            :set ($CheckHealthInterfaceDown->$IntName) false;
          }
        }
      } do={ 
        :log debug ($ScriptName . " - Error checking interface: " . $IntName);
      }
    }
  }

  # ============================================================================
  # INTERNET CONNECTIVITY MONITORING
  # ============================================================================
  
  :local InternetUp false;
  :onerror PingErr {
    :local PingResult [:ping 8.8.8.8 count=2];
    :if ([:len $PingResult] > 0) do={ :set InternetUp true; }
  } do={ :set InternetUp false; }
  
  :if ($InternetUp = false && $CheckHealthInternetConnectivity = true) do={
    $SendTelegram2 ({ silent=false; \
      subject="🌐 Internet Connectivity Lost"; \
      message=("Router " . $Identity . " cannot reach the internet.\n\nCheck WAN interface and routing.") });
    :set CheckHealthInternetConnectivity false;
    :log warning ($ScriptName . " - Internet connectivity lost");
  }
  
  :if ($InternetUp = true && $CheckHealthInternetConnectivity = false) do={
    $SendTelegram2 ({ silent=true; \
      subject="✅ Internet Connectivity Restored"; \
      message=("Router " . $Identity . " internet connectivity has been restored.") });
    :set CheckHealthInternetConnectivity true;
    :log info ($ScriptName . " - Internet connectivity restored");
  }

  # ============================================================================
  # SYSTEM UPTIME CHECK
  # ============================================================================
  
  :local Uptime [ /system/resource/get uptime ];
  :if ($Uptime < 5m) do={
    $SendTelegram2 ({ silent=false; \
      subject="🔄 System Restarted"; \
      message=("Router " . $Identity . " has restarted.\n\n" . \
        "Uptime: " . $Uptime . "\nVersion: " . ($Resource->"version") . "\nBoard: " . ($Resource->"board-name")) });
    :log info ($ScriptName . " - System recently restarted");
  }

  :log info ($ScriptName . " - Health check completed");
  :set ExitOK true;
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Monitoring failed: " . $Err);
  }
}
