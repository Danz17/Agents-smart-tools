#!rsc by RouterOS
# MikroTik Telegram Bot - Daily Summary Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Sends daily status summary via Telegram
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
  :global SendDailySummary;
  :global DailySummaryTime;
  :global DailySummaryLastSent;

  # Imported functions
  :global SendTelegram2;
  :global FormatBytes;

  # Check if daily summary is enabled
  :if ($SendDailySummary != true) do={
    :log debug ($ScriptName . " - Daily summary is disabled");
    :set ExitOK true;
    :error false;
  }

  # Check if already sent today
  :local Today [/system clock get date];
  :if ($DailySummaryLastSent = $Today) do={
    :log debug ($ScriptName . " - Daily summary already sent today");
    :set ExitOK true;
    :error false;
  }

  # Check if it's time to send (within 5 minutes of configured time)
  :local CurrentTime [/system clock get time];
  :local TargetTime [:totime $DailySummaryTime];
  :local TimeDiff ($CurrentTime - $TargetTime);
  :if ($TimeDiff < 0s) do={ :set TimeDiff ($TimeDiff * -1); }
  
  :if ($TimeDiff > 5m) do={
    :log debug ($ScriptName . " - Not time for daily summary yet");
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

  :if ([:typeof $FormatBytes] != "array") do={
    :set FormatBytes do={
      :local Bytes [:tonum $1]; :local Units ({"B"; "KB"; "MB"; "GB"; "TB"}); :local UnitIndex 0;
      :while ($Bytes >= 1024 && $UnitIndex < 4) do={ :set Bytes ($Bytes / 1024); :set UnitIndex ($UnitIndex + 1); }
      :return ([:tostr $Bytes] . ($Units->$UnitIndex));
    }
  }

  :log info ($ScriptName . " - Generating daily summary");

  # ============================================================================
  # GATHER SYSTEM INFORMATION
  # ============================================================================
  
  :local Resource [/system resource get];
  :local Uptime ($Resource->"uptime");
  :local CPULoad ($Resource->"cpu-load");
  :local TotalRAM ($Resource->"total-memory");
  :local FreeRAM ($Resource->"free-memory");
  :local UsedRAM ($TotalRAM - $FreeRAM);
  :local RAMPercent ($UsedRAM * 100 / $TotalRAM);
  :local TotalHDD ($Resource->"total-hdd-space");
  :local FreeHDD ($Resource->"free-hdd-space");
  :local UsedHDD ($TotalHDD - $FreeHDD);
  :local HDDPercent ($UsedHDD * 100 / $TotalHDD);
  :local Version ($Resource->"version");
  :local Board ($Resource->"board-name");

  # Interface statistics
  :local IntTotal [:len [/interface find]];
  :local IntRunning [:len [/interface find where running=yes]];
  :local IntDisabled [:len [/interface find where disabled=yes]];

  # Network statistics
  :local ConnCount 0;
  :onerror ConnErr { :set ConnCount [:len [/ip/firewall/connection find]]; } do={ }
  
  :local DHCPLeases 0;
  :onerror DHCPErr { :set DHCPLeases [:len [/ip/dhcp-server/lease find where status=bound]]; } do={ }

  # Wireless statistics
  :local WirelessClients 0;
  :local WirelessSection "";
  :onerror WirelessErr {
    :local WIntCount [:len [/interface wireless find]];
    :if ($WIntCount > 0) do={
      :foreach WInt in=[/interface wireless find] do={
        :local WName [/interface wireless get $WInt name];
        :onerror RegErr {
          :local RegCount [:len [/interface wireless registration-table find where interface=$WName]];
          :set WirelessClients ($WirelessClients + $RegCount);
        } do={ }
      }
      :set WirelessSection ("\n📡 *Wireless:*\n• Clients: " . $WirelessClients . "\n");
    }
  } do={ }

  # Security statistics
  :local FirewallDropped 0;
  :onerror FWErr {
    :foreach Rule in=[/ip/firewall/filter find where action=drop] do={
      :local Bytes [/ip/firewall/filter get $Rule bytes];
      :set FirewallDropped ($FirewallDropped + $Bytes);
    }
  } do={ }

  # Log statistics
  :local ErrorCount 0;
  :local WarningCount 0;
  :onerror LogErr {
    :set ErrorCount [:len [/log find where topics~"error"]];
    :set WarningCount [:len [/log find where topics~"warning"]];
  } do={ }

  # Backup status
  :local BackupCount 0;
  :local LastBackup "None";
  :onerror BackupErr {
    :local BackupFiles [/file find where name~"\\.backup\$"];
    :set BackupCount [:len $BackupFiles];
    :if ($BackupCount > 0) do={
      :local LatestBackup ($BackupFiles->($BackupCount - 1));
      :set LastBackup [/file get $LatestBackup name];
    }
  } do={ }

  # ============================================================================
  # BUILD SUMMARY MESSAGE
  # ============================================================================
  
  :local SummaryMsg ("📊 *Daily Status Summary*\n📅 " . $Today . "\n\n");
  
  # System Health
  :set SummaryMsg ($SummaryMsg . "🖥️ *System Health:*\n");
  :set SummaryMsg ($SummaryMsg . "• Uptime: " . $Uptime . "\n");
  :set SummaryMsg ($SummaryMsg . "• CPU: " . $CPULoad . "%\n");
  :set SummaryMsg ($SummaryMsg . "• RAM: " . $RAMPercent . "% (" . [$FormatBytes $UsedRAM] . "/" . [$FormatBytes $TotalRAM] . ")\n");
  :set SummaryMsg ($SummaryMsg . "• Disk: " . $HDDPercent . "% (" . [$FormatBytes $UsedHDD] . "/" . [$FormatBytes $TotalHDD] . ")\n\n");
  
  # Network Status
  :set SummaryMsg ($SummaryMsg . "🔌 *Network:*\n");
  :set SummaryMsg ($SummaryMsg . "• Interfaces: " . $IntRunning . "/" . $IntTotal . " up\n");
  :set SummaryMsg ($SummaryMsg . "• Connections: " . $ConnCount . "\n");
  :set SummaryMsg ($SummaryMsg . "• DHCP Leases: " . $DHCPLeases . "\n");
  
  # Wireless (if available)
  :if ([:len $WirelessSection] > 0) do={
    :set SummaryMsg ($SummaryMsg . $WirelessSection);
  }
  
  # Security
  :set SummaryMsg ($SummaryMsg . "\n🛡️ *Security:*\n");
  :set SummaryMsg ($SummaryMsg . "• Firewall Dropped: " . [$FormatBytes $FirewallDropped] . "\n");
  :set SummaryMsg ($SummaryMsg . "• Log Errors: " . $ErrorCount . "\n");
  :set SummaryMsg ($SummaryMsg . "• Log Warnings: " . $WarningCount . "\n\n");
  
  # Backup Status
  :set SummaryMsg ($SummaryMsg . "💾 *Backups:*\n");
  :set SummaryMsg ($SummaryMsg . "• Total: " . $BackupCount . " files\n");
  :set SummaryMsg ($SummaryMsg . "• Latest: " . $LastBackup . "\n\n");
  
  # System Info
  :set SummaryMsg ($SummaryMsg . "ℹ️ *System Info:*\n");
  :set SummaryMsg ($SummaryMsg . "• Version: " . $Version . "\n");
  :set SummaryMsg ($SummaryMsg . "• Board: " . $Board . "\n");

  # Health indicators
  :local HealthStatus "✅ All systems normal";
  :if ($CPULoad > 80 || $RAMPercent > 90 || $HDDPercent > 90) do={
    :set HealthStatus "⚠️ Some resources are high";
  }
  :if ($IntRunning < ($IntTotal - $IntDisabled)) do={
    :set HealthStatus "⚠️ Some interfaces are down";
  }
  :set SummaryMsg ($SummaryMsg . "\n" . $HealthStatus);

  # ============================================================================
  # SEND SUMMARY
  # ============================================================================
  
  $SendTelegram2 ({ origin=$ScriptName; silent=true; \
    subject="📊 Daily Summary"; message=$SummaryMsg });
  
  :set DailySummaryLastSent $Today;
  
  :log info ($ScriptName . " - Daily summary sent successfully");
  :set ExitOK true;
  
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Daily summary failed: " . $Err);
  }
}
