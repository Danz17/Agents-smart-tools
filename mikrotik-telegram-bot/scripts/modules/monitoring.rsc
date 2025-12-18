#!rsc by RouterOS
# MikroTik Telegram Bot - Monitoring Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# System monitoring with automatic alerts

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # Import configuration
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
  :global TelegramChatId;

  # Check if monitoring is enabled
  :if ($EnableAutoMonitoring != true) do={
    :log debug ($ScriptName . " - Monitoring is disabled");
    :set ExitOK true;
    :error false;
  }

  # URL encode helper
  :local UrlEncode do={
    :local String [ :tostr $1 ];
    :local Result "";
    :for I from=0 to=([:len $String] - 1) do={
      :local Char [:pick $String $I ($I + 1)];
      :if ($Char ~ "[A-Za-z0-9_.~-]") do={
        :set Result ($Result . $Char);
      } else={
        :if ($Char = " ") do={
          :set Result ($Result . "%20");
        } else={
          :if ($Char = "\n") do={
            :set Result ($Result . "%0A");
          } else={
            :set Result ($Result . $Char);
          }
        }
      }
    }
    :return $Result;
  }

  # Send notification function
  :local SendTelegram2 do={
    :local Notification $1;
    :global TelegramTokenId;
    :global TelegramChatId;
    :global Identity;
    
    :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . \
      ($Notification->"message"));
    
    :local HTTPData ("chat_id=" . $TelegramChatId . \
      "&disable_notification=" . ($Notification->"silent") . \
      "&parse_mode=Markdown");
    
    :onerror SendErr {
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]);
    } do={
      :log warning ("monitoring - Failed to send notification: " . $SendErr);
    }
  }

  # Format number with units
  :local HumanReadableNum do={
    :local Num [:tonum $1];
    :local Div [:tonum $2];
    :local Units ({""; "K"; "M"; "G"; "T"});
    :local UnitIndex 0;
    
    :while ($Num >= $Div && $UnitIndex < 4) do={
      :set Num ($Num / $Div);
      :set UnitIndex ($UnitIndex + 1);
    }
    
    :return ([:tostr $Num] . ($Units->$UnitIndex));
  }

  :log info ($ScriptName . " - Running system health check");

  # ============================================================================
  # CPU MONITORING
  # ============================================================================
  
  :local Resource [ /system/resource/get ];
  :local CurrentCPU (($Resource->"cpu-load") * 10);
  
  # Initialize if not set
  :if ([:typeof $CheckHealthCPUUtilization] != "num") do={
    :set CheckHealthCPUUtilization $CurrentCPU;
  }
  
  # 5-point moving average
  :set CheckHealthCPUUtilization (($CheckHealthCPUUtilization * 4 + $CurrentCPU) / 5);
  
  :if ($CheckHealthCPUUtilization > ($MonitorCPUThreshold * 10) && \
      $CheckHealthCPUUtilizationNotified != true) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="⚠️ CPU Utilization Alert"; \
      message=("CPU utilization on " . $Identity . " is high!\n\n" . \
        "Average: " . ($CheckHealthCPUUtilization / 10) . "%\n" . \
        "Threshold: " . $MonitorCPUThreshold . "%\n" . \
        "Current: " . ($Resource->"cpu-load") . "%") });
    :set CheckHealthCPUUtilizationNotified true;
    :log warning ($ScriptName . " - CPU utilization high: " . ($CheckHealthCPUUtilization / 10) . "%");
  }
  
  :if ($CheckHealthCPUUtilization < (($MonitorCPUThreshold - 10) * 10) && \
      $CheckHealthCPUUtilizationNotified = true) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=true; \
      subject="✅ CPU Utilization Recovered"; \
      message=("CPU utilization on " . $Identity . " returned to normal.\n\n" . \
        "Average: " . ($CheckHealthCPUUtilization / 10) . "%") });
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
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="⚠️ RAM Utilization Alert"; \
      message=("RAM utilization on " . $Identity . " is high!\n\n" . \
        "Used: " . $RAMPercent . "%\n" . \
        "Total: " . [$HumanReadableNum $TotalRAM 1024] . "B\n" . \
        "Used: " . [$HumanReadableNum $UsedRAM 1024] . "B\n" . \
        "Free: " . [$HumanReadableNum $FreeRAM 1024] . "B") });
    :set CheckHealthRAMUtilizationNotified true;
    :log warning ($ScriptName . " - RAM utilization high: " . $RAMPercent . "%");
  }
  
  :if ($RAMPercent < ($MonitorRAMThreshold - 10) && $CheckHealthRAMUtilizationNotified = true) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=true; \
      subject="✅ RAM Utilization Recovered"; \
      message=("RAM utilization on " . $Identity . " returned to normal.\n\n" . \
        "Used: " . $RAMPercent . "%") });
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
  
  :if ($HDDPercent >= $MonitorDiskThreshold) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="⚠️ Disk Usage Alert"; \
      message=("Disk usage on " . $Identity . " is high!\n\n" . \
        "Used: " . $HDDPercent . "%\n" . \
        "Total: " . [$HumanReadableNum $TotalHDD 1024] . "B\n" . \
        "Used: " . [$HumanReadableNum $UsedHDD 1024] . "B\n" . \
        "Free: " . [$HumanReadableNum $FreeHDD 1024] . "B") });
    :log warning ($ScriptName . " - Disk usage high: " . $HDDPercent . "%");
  }

  # ============================================================================
  # TEMPERATURE MONITORING
  # ============================================================================
  
  :onerror TempErr {
    :local TempVal [ /system/health/get value-name=temperature ];
    :if ([:typeof $TempVal] = "num" && $TempVal > $MonitorTempThreshold) do={
      $SendTelegram2 ({ origin=$ScriptName; silent=false; \
        subject="🌡️ Temperature Alert"; \
        message=("Temperature on " . $Identity . " is high!\n\n" . \
          "Current: " . $TempVal . "°C\n" . \
          "Threshold: " . $MonitorTempThreshold . "°C") });
      :log warning ($ScriptName . " - Temperature high: " . $TempVal . "°C");
    }
  } do={
    :log debug ($ScriptName . " - No temperature sensor available");
  }

  # ============================================================================
  # VOLTAGE MONITORING
  # ============================================================================
  
  :onerror VoltErr {
    :local Voltage [ /system/health/get voltage ];
    :if ($Voltage < $MonitorVoltageMin || $Voltage > $MonitorVoltageMax) do={
      $SendTelegram2 ({ origin=$ScriptName; silent=false; \
        subject="⚡ Voltage Alert"; \
        message=("Voltage on " . $Identity . " is out of range!\n\n" . \
          "Current: " . $Voltage . "V\n" . \
          "Expected: " . $MonitorVoltageMin . "-" . $MonitorVoltageMax . "V") });
      :log warning ($ScriptName . " - Voltage out of range: " . $Voltage . "V");
    }
  } do={
    :log debug ($ScriptName . " - No voltage sensor available");
  }

  # ============================================================================
  # INTERFACE MONITORING
  # ============================================================================
  
  :if ([:len $MonitorInterfaces] > 0) do={
    :local InterfaceList [:toarray $MonitorInterfaces];
    :foreach IntName in=$InterfaceList do={
      :onerror IntErr {
        :local Int [ /interface/get [find name=$IntName] ];
        
        # Check if interface is down
        :if (($Int->"running") = false && ($Int->"disabled") = false) do={
          $SendTelegram2 ({ origin=$ScriptName; silent=false; \
            subject="🔌 Interface Down Alert"; \
            message=("Interface " . $IntName . " on " . $Identity . " is down!") });
          :log warning ($ScriptName . " - Interface down: " . $IntName);
        }
        
        # Check for errors
        :onerror NoStats {
          :local Stats [ /interface/ethernet/get [find name=$IntName] ];
          :if (($Stats->"rx-error") > 1000 || ($Stats->"tx-error") > 1000) do={
            $SendTelegram2 ({ origin=$ScriptName; silent=false; \
              subject="⚠️ Interface Errors"; \
              message=("Interface " . $IntName . " on " . $Identity . " has errors!\n\n" . \
                "RX Errors: " . ($Stats->"rx-error") . "\n" . \
                "TX Errors: " . ($Stats->"tx-error")) });
            :log warning ($ScriptName . " - Interface errors: " . $IntName);
          }
        } do={ :log debug ($ScriptName . " - No ethernet stats for: " . $IntName); }
      } do={
        :log debug ($ScriptName . " - Interface not found: " . $IntName);
      }
    }
  }

  # ============================================================================
  # SYSTEM UPTIME CHECK
  # ============================================================================
  
  :local Uptime [ /system/resource/get uptime ];
  :if ($Uptime < 5m) do={
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="🔄 System Restarted"; \
      message=("Router " . $Identity . " has restarted.\n\n" . \
        "Uptime: " . $Uptime . "\n" . \
        "Version: " . ($Resource->"version") . "\n" . \
        "Board: " . ($Resource->"board-name")) });
    :log info ($ScriptName . " - System recently restarted");
  }

  :log info ($ScriptName . " - Health check completed");
  :set ExitOK true;
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Monitoring failed: " . $Err);
  }
}
