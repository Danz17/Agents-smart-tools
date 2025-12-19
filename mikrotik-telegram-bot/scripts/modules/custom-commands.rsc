#!rsc by RouterOS
# MikroTik Telegram Bot - Custom Commands Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Extended command handlers for user-friendly bot commands
# Dependencies: shared-functions

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

  # Import shared functions
  :global FormatBytes;

  # Fallback FormatBytes if module not loaded
  :if ([:typeof $FormatBytes] != "array") do={
    :set FormatBytes do={
      :local Bytes [:tonum $1];
      :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
      :local UnitIndex 0;
      :while ($Bytes >= 1024 && $UnitIndex < 4) do={
        :set Bytes ($Bytes / 1024);
        :set UnitIndex ($UnitIndex + 1);
      }
      :return ([:tostr $Bytes] . ($Units->$UnitIndex));
    }
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
    
    :local TotalRAM ($Resource->"total-memory");
    :local FreeRAM ($Resource->"free-memory");
    :local UsedRAM ($TotalRAM - $FreeRAM);
    :local RAMPercent ($UsedRAM * 100 / $TotalRAM);
    :set StatusMsg ($StatusMsg . "• RAM: " . $RAMPercent . "% (" . ($UsedRAM / 1048576) . "MB / " . ($TotalRAM / 1048576) . "MB)\n");
    
    :local TotalHDD ($Resource->"total-hdd-space");
    :local FreeHDD ($Resource->"free-hdd-space");
    :local UsedHDD ($TotalHDD - $FreeHDD);
    :local HDDPercent ($UsedHDD * 100 / $TotalHDD);
    :set StatusMsg ($StatusMsg . "• Disk: " . $HDDPercent . "% (" . ($UsedHDD / 1048576) . "MB / " . ($TotalHDD / 1048576) . "MB)\n\n");
    
    :set StatusMsg ($StatusMsg . "⏱️ *Uptime:* " . ($Resource->"uptime") . "\n");
    :set StatusMsg ($StatusMsg . "📦 *Version:* " . ($Resource->"version") . "\n");
    :set StatusMsg ($StatusMsg . "🏷️ *Board:* " . ($Resource->"board-name") . "\n\n");
    
    :local IntTotal [:len [/interface find]];
    :local IntRunning [:len [/interface find where running=yes]];
    :set StatusMsg ($StatusMsg . "🔌 *Interfaces:* " . $IntRunning . "/" . $IntTotal . " up\n");
    
    :onerror ConnErr {
      :local ConnCount [:len [/ip/firewall/connection find]];
      :set StatusMsg ($StatusMsg . "🔗 *Connections:* " . $ConnCount . "\n");
    } do={ }
    
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
        :local Status "❌";
        :if ($IntRunning = true) do={ :set Status "✅"; }
        :set IntMsg ($IntMsg . $Status . " *" . $IntName . "*\n");
        
        :onerror StatsErr {
          :local Stats [/interface get $Int];
          :set IntMsg ($IntMsg . "   RX: " . (($Stats->"rx-byte") / 1048576) . "MB");
          :set IntMsg ($IntMsg . " | TX: " . (($Stats->"tx-byte") / 1048576) . "MB\n");
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
    
    :onerror DHCPErr {
      :foreach Lease in=[/ip/dhcp-server/lease find where status=bound] do={
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
        
        :if ($LeaseCount >= 20) do={
          :set DHCPMsg ($DHCPMsg . "\n_Showing first 20 leases_\n");
          :return $DHCPMsg;
        }
      }
    } do={ :set DHCPMsg ($DHCPMsg . "_Error reading DHCP leases_"); }
    
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
    
    # Sanitize filter
    :if ([:len $Filter] = 0) do={ :set Filter ".*"; }
    :if ([:len $Filter] > 50) do={ :set Filter [:pick $Filter 0 50]; }
    
    :onerror LogErr {
      :foreach LogEntry in=[/log find] do={
        :local LogData [/log get $LogEntry];
        :local Message ($LogData->"message");
        
        :if ($Message ~ $Filter || $Filter = ".*") do={
          :local Time ($LogData->"time");
          :local Topics ($LogData->"topics");
          
          :set LogCount ($LogCount + 1);
          :set LogMsg ($LogMsg . "`" . $Time . "` *" . $Topics . "*\n");
          :set LogMsg ($LogMsg . $Message . "\n\n");
          
          :if ($LogCount >= 10) do={
            :set LogMsg ($LogMsg . "_Showing last 10 entries_\n");
            :return $LogMsg;
          }
        }
      }
    } do={ :set LogMsg ($LogMsg . "_Error reading logs_"); }
    
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
      :onerror UpdateErr {
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
          :set UpdateMsg ($UpdateMsg . "⬆️ Update available!\nUse `/update install` to update");
        }
        
        :return $UpdateMsg;
      } do={
        :return ("❌ Failed to check updates: " . $UpdateErr);
      }
    }
    
    :if ($Action = "install") do={
      :return "⚠️ Installing updates will reboot the router!\nUse: `/system package update install`";
    }
    
    :return "Usage: `/update [check|install]`";
  }

  # ============================================================================
  # /traffic - Interface Traffic Command
  # ============================================================================
  
  :global CommandTraffic do={
    :local InterfaceName [:tostr $1];
    :global FormatBytes;
    
    :if ([:len $InterfaceName] = 0) do={ :set InterfaceName "ether1"; }
    
    :onerror TrafficErr {
      :local Int [/interface find name=$InterfaceName];
      :if ([:len $Int] = 0) do={
        :return ("❌ Interface `" . $InterfaceName . "` not found\n\nUsage: `/traffic [interface]`");
      }
      
      :local Traffic [/interface get $Int];
      :local TrafficMsg ("📊 *Traffic: " . $InterfaceName . "*\n\n");
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
  # /reboot - Reboot Command (requires confirmation)
  # ============================================================================
  
  :global CommandReboot do={
    :local Confirmation [:tostr $1];
    :global Identity;
    
    :if ($Confirmation = "confirm") do={
      :log warning "Reboot initiated via Telegram bot";
      :return "🔄 Rebooting router now...\n\nI'll be back online shortly!";
    } else={
      :return ("⚠️ *Reboot Confirmation Required*\n\n" . \
        "To reboot the router, send:\n`/reboot confirm`\n\n" . \
        "Or use: `! " . $Identity . "` then `/system reboot`");
    }
  }

  # ============================================================================
  # REGISTRATION COMPLETE
  # ============================================================================
  
  :log info ($ScriptName . " - Custom command handlers loaded");
  :set ExitOK true;
  
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Command handler initialization failed: " . $Err);
  }
}
