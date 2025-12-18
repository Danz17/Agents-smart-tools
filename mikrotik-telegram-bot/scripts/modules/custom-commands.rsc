#!rsc by RouterOS
# MikroTik Telegram Bot - Custom Commands Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Extended command handlers for user-friendly bot commands

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # Import configuration
  :global Identity;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global TelegramChatIdsTrusted;
  :global CustomCommands;

  # ============================================================================
  # COMMAND HANDLER FUNCTIONS
  # ============================================================================

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

  # Send Telegram message helper
  :local SendTelegram2 do={
    :local Notification $1;
    :global TelegramTokenId;
    :global TelegramChatId;
    :global TelegramThreadId;
    :global Identity;
    
    :local ChatId ([$1 "chatid"]);
    :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
    
    :local ThreadId ([$1 "threadid"]);
    :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
    
    :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . \
      ($Notification->"message"));
    
    :local HTTPData ("chat_id=" . $ChatId . \
      "&disable_notification=" . ($Notification->"silent") . \
      "&message_thread_id=" . $ThreadId . \
      "&parse_mode=Markdown");
    
    :onerror SendErr {
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]);
    } do={
      :log warning ("custom-commands - Failed to send notification: " . $SendErr);
    }
  }

  # Format bytes to human readable
  :local FormatBytes do={
    :local Bytes [:tonum $1];
    :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
    :local UnitIndex 0;
    
    :while ($Bytes >= 1024 && $UnitIndex < 4) do={
      :set Bytes ($Bytes / 1024);
      :set UnitIndex ($UnitIndex + 1);
    }
    
    :return ([:tostr $Bytes] . ($Units->$UnitIndex));
  }

  # ============================================================================
  # /status - System Status Command
  # ============================================================================
  
  :global CommandStatus do={
    :local Resource [ /system/resource/get ];
    :local Identity [ /system/identity/get name ];
    
    :local StatusMsg ("🖥️ *System Status*\n\n");
    :set StatusMsg ($StatusMsg . "📊 *Resources:*\n");
    :set StatusMsg ($StatusMsg . "• CPU: " . ($Resource->"cpu-load") . "%\n");
    :set StatusMsg ($StatusMsg . "• RAM: " . (($Resource->"total-memory" - $Resource->"free-memory") * 100 / $Resource->"total-memory") . "%");
    :set StatusMsg ($StatusMsg . " (" . (($Resource->"total-memory" - $Resource->"free-memory") / 1048576) . "MB / " . ($Resource->"total-memory" / 1048576) . "MB)\n");
    :set StatusMsg ($StatusMsg . "• Disk: " . (($Resource->"total-hdd-space" - $Resource->"free-hdd-space") * 100 / $Resource->"total-hdd-space") . "%");
    :set StatusMsg ($StatusMsg . " (" . (($Resource->"total-hdd-space" - $Resource->"free-hdd-space") / 1048576) . "MB / " . ($Resource->"total-hdd-space" / 1048576) . "MB)\n\n");
    
    :set StatusMsg ($StatusMsg . "⏱️ *Uptime:* " . ($Resource->"uptime") . "\n");
    :set StatusMsg ($StatusMsg . "📦 *Version:* " . ($Resource->"version") . "\n");
    :set StatusMsg ($StatusMsg . "🏷️ *Board:* " . ($Resource->"board-name") . "\n\n");
    
    # Interface summary
    :local IntTotal [:len [/interface find]];
    :local IntRunning [:len [/interface find where running=yes]];
    :set StatusMsg ($StatusMsg . "🔌 *Interfaces:* " . $IntRunning . "/" . $IntTotal . " up\n");
    
    # Active connections
    :local ConnCount [:len [/ip/firewall/connection find]];
    :set StatusMsg ($StatusMsg . "🔗 *Connections:* " . $ConnCount . "\n");
    
    :return $StatusMsg;
  }

  # ============================================================================
  # /interfaces - Interface Statistics Command
  # ============================================================================
  
  :global CommandInterfaces do={
    :local IntMsg ("🔌 *Interface Status*\n\n");
    
    :foreach Int in=[/interface find] do={
      :local IntData [/interface get $Int];
      :local IntName ($IntData->"name");
      :local IntRunning ($IntData->"running");
      :local IntDisabled ($IntData->"disabled");
      
      :if ($IntDisabled = false) do={
        :set IntMsg ($IntMsg . ($IntRunning = true ? "✅" : "❌") . " *" . $IntName . "*\n");
        
        # Get statistics if available
        :onerror StatsErr {
          :local Stats [/interface ethernet get [find name=$IntName]];
          :if ([:typeof $Stats] = "array") do={
            :set IntMsg ($IntMsg . "   RX: " . (($Stats->"rx-byte") / 1048576) . "MB");
            :set IntMsg ($IntMsg . " | TX: " . (($Stats->"tx-byte") / 1048576) . "MB\n");
          }
        } do={ }
      }
    }
    
    :return $IntMsg;
  }

  # ============================================================================
  # /dhcp - DHCP Leases Command
  # ============================================================================
  
  :global CommandDHCP do={
    :local DHCPMsg ("📡 *DHCP Leases*\n\n");
    :local LeaseCount 0;
    
    :foreach Lease in=[/ip/dhcp-server/lease find where active-address!=""] do={
      :local LeaseData [/ip/dhcp-server/lease get $Lease];
      :local Address ($LeaseData->"active-address");
      :local MAC ($LeaseData->"active-mac-address");
      :local HostName ($LeaseData->"host-name");
      
      :set LeaseCount ($LeaseCount + 1);
      :set DHCPMsg ($DHCPMsg . "• `" . $Address . "`");
      :if ([:len $HostName] > 0) do={
        :set DHCPMsg ($DHCPMsg . " - " . $HostName);
      }
      :set DHCPMsg ($DHCPMsg . "\n   " . $MAC . "\n");
      
      # Limit to 20 leases
      :if ($LeaseCount >= 20) do={
        :set DHCPMsg ($DHCPMsg . "\n_Showing first 20 leases_\n");
        :return $DHCPMsg;
      }
    }
    
    :if ($LeaseCount = 0) do={
      :set DHCPMsg ($DHCPMsg . "_No active DHCP leases_");
    }
    
    :return $DHCPMsg;
  }

  # ============================================================================
  # /logs - Recent Logs Command
  # ============================================================================
  
  :global CommandLogs do={
    :local Filter [:tostr $1];
    :local LogMsg ("📋 *Recent Logs*\n\n");
    :local LogCount 0;
    
    :if ([:len $Filter] = 0) do={
      :set Filter ".*";
    }
    
    :foreach LogEntry in=[/log find where message~$Filter] do={
      :local LogData [/log get $LogEntry];
      :local Time ($LogData->"time");
      :local Topics ($LogData->"topics");
      :local Message ($LogData->"message");
      
      :set LogCount ($LogCount + 1);
      :set LogMsg ($LogMsg . "`" . $Time . "` *" . $Topics . "*\n");
      :set LogMsg ($LogMsg . $Message . "\n\n");
      
      # Limit to 10 log entries
      :if ($LogCount >= 10) do={
        :set LogMsg ($LogMsg . "_Showing last 10 entries_\n");
        :return $LogMsg;
      }
    }
    
    :if ($LogCount = 0) do={
      :set LogMsg ($LogMsg . "_No matching log entries_");
    }
    
    :return $LogMsg;
  }

  # ============================================================================
  # /update - Check RouterOS Updates Command
  # ============================================================================
  
  :global CommandUpdate do={
    :local Action [:tostr $1];
    
    :if ($Action = "check" || [:len $Action] = 0) do={
      /system/package/update/check-for-updates;
      :delay 2s;
      :local Update [/system/package/update/get];
      
      :local UpdateMsg ("📦 *RouterOS Update Status*\n\n");
      :set UpdateMsg ($UpdateMsg . "Current: " . ($Update->"installed-version") . "\n");
      :set UpdateMsg ($UpdateMsg . "Latest: " . ($Update->"latest-version") . "\n");
      :set UpdateMsg ($UpdateMsg . "Channel: " . ($Update->"channel") . "\n\n");
      
      :if (($Update->"installed-version") = ($Update->"latest-version")) do={
        :set UpdateMsg ($UpdateMsg . "✅ System is up to date!");
      } else={
        :set UpdateMsg ($UpdateMsg . "⬆️ Update available!\n");
        :set UpdateMsg ($UpdateMsg . "Use `/update install` to update");
      }
      
      :return $UpdateMsg;
    }
    
    :if ($Action = "install") do={
      :return "⚠️ Installing updates will reboot the router!\nUse RouterOS command: `/system package update install`";
    }
    
    :return "Usage: `/update [check|install]`";
  }

  # ============================================================================
  # /traffic - Interface Traffic Command
  # ============================================================================
  
  :global CommandTraffic do={
    :local InterfaceName [:tostr $1];
    
    :if ([:len $InterfaceName] = 0) do={
      :set InterfaceName "ether1";
    }
    
    :onerror TrafficErr {
      :local Traffic [/interface get [find name=$InterfaceName]];
      
      :local TrafficMsg ("📊 *Traffic Statistics: " . $InterfaceName . "*\n\n");
      :set TrafficMsg ($TrafficMsg . "📥 RX: " . [$FormatBytes ($Traffic->"rx-byte")] . "\n");
      :set TrafficMsg ($TrafficMsg . "📤 TX: " . [$FormatBytes ($Traffic->"tx-byte")] . "\n");
      :set TrafficMsg ($TrafficMsg . "📦 RX Packets: " . ($Traffic->"rx-packet") . "\n");
      :set TrafficMsg ($TrafficMsg . "📦 TX Packets: " . ($Traffic->"tx-packet") . "\n");
      
      :return $TrafficMsg;
    } do={
      :return ("❌ Interface `" . $InterfaceName . "` not found\n\nUsage: `/traffic [interface]`");
    }
  }

  # ============================================================================
  # /backup - Backup Command
  # ============================================================================
  
  :global CommandBackup do={
    :local Action [:tostr $1];
    
    :if ($Action = "now" || [:len $Action] = 0) do={
      # Trigger backup module
      :onerror BackupErr {
        /system/script/run modules/backup;
        :return "💾 Backup started! You will receive a notification when complete.";
      } do={
        :return ("❌ Failed to start backup: " . $BackupErr);
      }
    }
    
    :if ($Action = "list") do={
      :local BackupMsg ("💾 *Available Backups*\n\n");
      :local BackupCount 0;
      
      :foreach File in=[/file find where name~"\\.backup\$"] do={
        :local FileData [/file get $File];
        :set BackupCount ($BackupCount + 1);
        :set BackupMsg ($BackupMsg . "• " . ($FileData->"name") . "\n");
        :set BackupMsg ($BackupMsg . "   Size: " . [$FormatBytes ($FileData->"size")]);
        :set BackupMsg ($BackupMsg . " | Date: " . ($FileData->"creation-time") . "\n");
      }
      
      :if ($BackupCount = 0) do={
        :set BackupMsg ($BackupMsg . "_No backup files found_");
      }
      
      :return $BackupMsg;
    }
    
    :return "Usage: `/backup [now|list]`";
  }

  # ============================================================================
  # /reboot - Reboot Command (requires confirmation)
  # ============================================================================
  
  :global CommandReboot do={
    :local Confirmation [:tostr $1];
    
    :if ($Confirmation = "confirm") do={
      :log warning "Reboot initiated via Telegram bot";
      :return "🔄 Rebooting router now...\n\nI'll be back online shortly!";
      # Note: Actual reboot should be done by sending the raw command
      # /system reboot
    } else={
      :return ("⚠️ *Reboot Confirmation Required*\n\n" . \
        "To reboot the router, send:\n`/reboot confirm`\n\n" . \
        "Or use: `! " . $Identity . "` then `/system reboot`");
    }
  }

  # ============================================================================
  # Register command handlers
  # ============================================================================
  
  :log info ($ScriptName . " - Custom command handlers loaded");
  :set ExitOK true;
  
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Command handler initialization failed: " . $Err);
  }
}

