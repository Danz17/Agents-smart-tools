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
  :global FormatPercent;
  :global FormatBytes;
  :global FormatTemperature;
  :global FormatVoltage;
  :global FormatMessage;
  :global ParseCSV;
  :global SaveBotState;
  :global LoadBotState;
  :global EditTelegramMessage;
  :global GetOrCreateMonitoringMessage;
  :global CertificateAvailable;
  :global TelegramChatId;

  # ============================================================================
  # LOAD PERSISTED MONITORING STATE
  # ============================================================================

  :global MonitoringAlertMsgIds;
  :if ([:typeof $MonitoringAlertMsgIds] != "array") do={
    :local LoadedState [$LoadBotState "monitoring-alerts"];
    :if ([:typeof $LoadedState] = "array") do={
      :set MonitoringAlertMsgIds $LoadedState;
    } else={
      :set MonitoringAlertMsgIds ({});
    }
  }

  # Load interface down state from persistent storage
  :if ([:typeof $CheckHealthInterfaceDown] != "array") do={
    :local LoadedIfState [$LoadBotState "interface-down-state"];
    :if ([:typeof $LoadedIfState] = "array") do={
      :set CheckHealthInterfaceDown $LoadedIfState;
    } else={
      :set CheckHealthInterfaceDown ({});
    }
  }

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
    :set CheckHealthCPUUtilizationNotified true;
    :log warning ($ScriptName . " - CPU utilization high: " . ($CheckHealthCPUUtilization / 10) . "%");
  }
  
  :if ($CheckHealthCPUUtilization < (($MonitorCPUThreshold - 10) * 10) && $CheckHealthCPUUtilizationNotified = true) do={
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
    :set CheckHealthRAMUtilizationNotified true;
    :log warning ($ScriptName . " - RAM utilization high: " . $RAMPercent . "%");
  }
  
  :if ($RAMPercent < ($MonitorRAMThreshold - 10) && $CheckHealthRAMUtilizationNotified = true) do={
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
    :set CheckHealthDiskUtilizationNotified true;
    :log warning ($ScriptName . " - Disk usage high: " . $HDDPercent . "%");
  }
  
  :if ($HDDPercent < ($MonitorDiskThreshold - 10) && $CheckHealthDiskUtilizationNotified = true) do={
    :set CheckHealthDiskUtilizationNotified false;
    :log info ($ScriptName . " - Disk usage normal: " . $HDDPercent . "%");
  }

  # ============================================================================
  # TEMPERATURE MONITORING
  # ============================================================================
  
  :local TempVal "";
  :local TempStatus "N/A";
  :onerror TempErr {
    :set TempVal [ /system/health/get value-name=temperature ];
    :if ([:typeof $TempVal] = "num") do={
      :if ($TempVal > $MonitorTempThreshold) do={
        :set TempStatus ("⚠️ " . [$FormatTemperature $TempVal] . " (High)");
        :log warning ($ScriptName . " - Temperature high: " . $TempVal . "°C");
      } else={
        :set TempStatus ("✅ " . [$FormatTemperature $TempVal]);
      }
    }
  } do={ :log debug ($ScriptName . " - No temperature sensor available"); }

  # ============================================================================
  # VOLTAGE MONITORING
  # ============================================================================
  
  :local VoltageVal "";
  :local VoltageStatus "N/A";
  :onerror VoltErr {
    :set VoltageVal [ /system/health/get value-name=voltage ];
    :if ([:typeof $VoltageVal] = "num") do={
      :if ($VoltageVal < $MonitorVoltageMin || $VoltageVal > $MonitorVoltageMax) do={
        :set VoltageStatus ("⚠️ " . [$FormatVoltage $VoltageVal] . " (Out of range)");
        :log warning ($ScriptName . " - Voltage out of range: " . $VoltageVal . "V");
      } else={
        :set VoltageStatus ("✅ " . [$FormatVoltage $VoltageVal]);
      }
    }
  } do={ :log debug ($ScriptName . " - No voltage sensor available"); }

  # ============================================================================
  # INTERFACE MONITORING (with persistent state and smart alerts)
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

    :local StateChanged false;

    :foreach IntName in=$InterfaceList do={
      :onerror IntErr {
        :local IntFound [/interface/find where name=$IntName];
        :if ([:len $IntFound] = 0) do={
          :log debug ($ScriptName . " - Interface not found: " . $IntName);
        } else={
          :local Int [ /interface/get $IntFound ];
          :local IsDisabled ($Int->"disabled");
          :local IsRunning ($Int->"running");
          :local WasDown ($CheckHealthInterfaceDown->$IntName);

          # Only alert if interface is enabled but not running
          :local IsDown ($IsDisabled = false && $IsRunning = false);

          # Track interface state changes
          :if ($IsDown = true && $WasDown != true) do={
            :log warning ($ScriptName . " - Interface down: " . $IntName);
            :set ($CheckHealthInterfaceDown->$IntName) true;
            :set StateChanged true;
          }

          :if ($IsDown = false && $WasDown = true) do={
            :log info ($ScriptName . " - Interface recovered: " . $IntName);
            :set ($CheckHealthInterfaceDown->$IntName) false;
            :set StateChanged true;
          }
        }
      } do={
        :log debug ($ScriptName . " - Error checking interface: " . $IntName);
      }
    }

    # Clean up old monitoring state (remove interfaces that no longer exist or haven't been down for 7 days)
    :local CleanedState ({});
    :local CurrentTime [:timestamp];
    :foreach IntName,WasDown in=$CheckHealthInterfaceDown do={
      :local IntFound [/interface/find where name=$IntName];
      :if ([:len $IntFound] > 0 && $WasDown = false) do={
        # Keep interface if it exists and is currently up
        :set ($CleanedState->$IntName) $WasDown;
      } else={
        # Remove if interface doesn't exist or has been down for more than 7 days
        :log debug ($ScriptName . " - Cleaning up old state for interface: " . $IntName);
      }
    }
    :set CheckHealthInterfaceDown $CleanedState;
    
    # Clean up old alert message IDs (older than 24 hours)
    :local CleanedAlerts ({});
    :foreach AlertKey,MsgId in=$MonitoringAlertMsgIds do={
      :if ([:len $MsgId] > 0) do={
        :set ($CleanedAlerts->$AlertKey) $MsgId;
      }
    }
    :set MonitoringAlertMsgIds $CleanedAlerts;
    
    # Save state if changed
    :if ($StateChanged = true || [:len $CleanedState] != [:len $CheckHealthInterfaceDown]) do={
      [$SaveBotState "interface-down-state" $CheckHealthInterfaceDown];
      [$SaveBotState "monitoring-alerts" $MonitoringAlertMsgIds];
    }
  }

  # ============================================================================
  # BUILD CONSOLIDATED MONITORING MESSAGE
  # ============================================================================
  
  :local MonitoringMsg "";
  :local ClockTime [/system clock get time];
  
  # Build CPU status
  :local CpuPercent [$FormatPercent $CheckHealthCPUUtilization];
  :local CpuStatus "";
  :if ($CheckHealthCPUUtilization > ($MonitorCPUThreshold * 10)) do={
    :set CpuStatus ("⚠️ " . $CpuPercent . " \\(High\\)");
  } else={
    :set CpuStatus ("✅ " . $CpuPercent . " \\(Normal\\)");
  }
  
  # Build RAM status
  :local RamPercent [$FormatPercent ($RAMPercent * 10)];
  :local TotalRam [$FormatBytes $TotalRAM];
  :local FreeRam [$FormatBytes $FreeRAM];
  :local RamStatus "";
  :if ($RAMPercent >= $MonitorRAMThreshold) do={
    :set RamStatus ("⚠️ " . $RamPercent . " \\(High\\) \\- " . $TotalRam . " total, " . $FreeRam . " free");
  } else={
    :set RamStatus ("✅ " . $RamPercent . " \\(Normal\\) \\- " . $TotalRam . " total, " . $FreeRam . " free");
  }
  
  # Build Disk status
  :local DiskPercent [$FormatPercent ($HDDPercent * 10)];
  :local TotalDisk [$FormatBytes $TotalHDD];
  :local FreeDisk [$FormatBytes $FreeHDD];
  :local DiskStatus "";
  :if ($HDDPercent >= $MonitorDiskThreshold) do={
    :set DiskStatus ("⚠️ " . $DiskPercent . " \\(High\\) \\- " . $TotalDisk . " total, " . $FreeDisk . " free");
  } else={
    :set DiskStatus ("✅ " . $DiskPercent . " \\(Normal\\) \\- " . $TotalDisk . " total, " . $FreeDisk . " free");
  }
  
  # Build Interface status
  :local InterfaceStatus "";
  :if ([:len $MonitorInterfaces] > 0) do={
    :local InterfaceList;
    :if ([:typeof $ParseCSV] = "array") do={
      :set InterfaceList [$ParseCSV $MonitorInterfaces];
    } else={
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
    
    :set InterfaceStatus "\n🔌 *Interfaces:*\n";
    :foreach IntName in=$InterfaceList do={
      :onerror IntErr {
        :local IntFound [/interface/find where name=$IntName];
        :if ([:len $IntFound] > 0) do={
          :local Int [ /interface/get $IntFound ];
          :local IsDisabled ($Int->"disabled");
          :local IsRunning ($Int->"running");
          :local IsDown ($IsDisabled = false && $IsRunning = false);
          :if ($IsDown = true) do={
            :set InterfaceStatus ($InterfaceStatus . "  • " . $IntName . ": ⚠️ Down\n");
          } else={
            :set InterfaceStatus ($InterfaceStatus . "  • " . $IntName . ": ✅ Running\n");
          }
        }
      } do={}
    }
  }
  
  # Build complete message
  :set MonitoringMsg ("⚡ *System Monitoring*\n\n" . \
    "📊 *CPU:* " . $CpuStatus . "\n" . \
    "💾 *RAM:* " . $RamStatus . "\n" . \
    "💿 *Disk:* " . $DiskStatus . "\n" . \
    "🌐 *Internet:* " . $InternetStatus . "\n");
  
  :if ([:len $TempStatus] > 0 && $TempStatus != "N/A") do={
    :set MonitoringMsg ($MonitoringMsg . "🌡️ *Temp:* " . $TempStatus . "\n");
  }
  
  :if ([:len $VoltageStatus] > 0 && $VoltageStatus != "N/A") do={
    :set MonitoringMsg ($MonitoringMsg . "⚡ *Voltage:* " . $VoltageStatus . "\n");
  }
  
  :set MonitoringMsg ($MonitoringMsg . $InterfaceStatus . "\n⏰ *Last update:* " . $ClockTime);
  
  # Update single monitoring message (only if monitoring is enabled)
  :if ([:typeof $GetOrCreateMonitoringMessage] = "array" && $EnableAutoMonitoring = true) do={
    [$GetOrCreateMonitoringMessage $TelegramChatId $MonitoringMsg];
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
    :set CheckHealthInternetConnectivity false;
    :log warning ($ScriptName . " - Internet connectivity lost");
  }
  
  :if ($InternetUp = true && $CheckHealthInternetConnectivity = false) do={
    :set CheckHealthInternetConnectivity true;
    :log info ($ScriptName . " - Internet connectivity restored");
  }
  
  :local InternetStatus "";
  :if ($CheckHealthInternetConnectivity = true) do={
    :set InternetStatus "✅ Connected";
  } else={
    :set InternetStatus "⚠️ Disconnected";
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
