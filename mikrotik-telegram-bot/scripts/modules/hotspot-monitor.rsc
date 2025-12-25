#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Hotspot Monitoring Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Hotspot user monitoring, management, and statistics
# Dependencies: shared-functions, telegram-api

# ============================================================================
# LOADING GUARD
# ============================================================================

:global HotspotMonitorLoaded;
:if ($HotspotMonitorLoaded = true) do={
  :return;
}

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error "[hotspot-monitor] - Failed to load shared-functions";
    :return;
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/telegram-api";
  } do={
    :log warning "[hotspot-monitor] - Telegram API not available";
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global FormatBytes;
:global FormatDuration;
:global TelegramChatId;
:global TelegramThreadId;

# ============================================================================
# CONFIGURATION
# ============================================================================

:global HotspotMonitorEnabled;
:global HotspotAlertOnConnect;
:global HotspotAlertOnDisconnect;
:global HotspotTrackBandwidth;

:if ([:typeof $HotspotMonitorEnabled] != "bool") do={ :set HotspotMonitorEnabled true; }
:if ([:typeof $HotspotAlertOnConnect] != "bool") do={ :set HotspotAlertOnConnect false; }
:if ([:typeof $HotspotAlertOnDisconnect] != "bool") do={ :set HotspotAlertOnDisconnect false; }
:if ([:typeof $HotspotTrackBandwidth] != "bool") do={ :set HotspotTrackBandwidth true; }

# ============================================================================
# CHECK IF HOTSPOT IS AVAILABLE
# ============================================================================

:global IsHotspotAvailable do={
  :onerror Err {
    :local Servers [/ip hotspot find];
    :return ([:len $Servers] > 0);
  } do={
    :return false;
  }
}

# ============================================================================
# GET ACTIVE HOTSPOT USERS
# ============================================================================

:global GetHotspotActiveUsers do={
  :local Users ({});

  :onerror Err {
    :foreach Active in=[/ip hotspot active find] do={
      :local UserData [/ip hotspot active get $Active];
      :local UserInfo ({
        "id"=[:tostr $Active];
        "user"=($UserData->"user");
        "address"=($UserData->"address");
        "mac-address"=($UserData->"mac-address");
        "uptime"=($UserData->"uptime");
        "server"=($UserData->"server");
        "bytes-in"=($UserData->"bytes-in");
        "bytes-out"=($UserData->"bytes-out");
        "packets-in"=($UserData->"packets-in");
        "packets-out"=($UserData->"packets-out");
        "idle-time"=($UserData->"idle-time")
      });
      :set ($Users->[:len $Users]) $UserInfo;
    }
  } do={
    :log warning ("[hotspot-monitor] - Error getting active users: " . $Err);
  }

  :return $Users;
}

# ============================================================================
# GET HOTSPOT USER COUNT
# ============================================================================

:global GetHotspotUserCount do={
  :onerror Err {
    :return [:len [/ip hotspot active find]];
  } do={
    :return 0;
  }
}

# ============================================================================
# FORMAT ACTIVE USERS LIST
# ============================================================================

:global FormatHotspotUsers do={
  :local Users $1;
  :local Page [:tonum $2];
  :local PageSize 5;

  :global FormatBytes;
  :global FormatDuration;

  :if ([:typeof $Page] != "num" || $Page < 1) do={ :set Page 1; }

  :local TotalUsers [:len $Users];
  :local TotalPages (($TotalUsers + $PageSize - 1) / $PageSize);
  :if ($TotalPages < 1) do={ :set TotalPages 1; }
  :if ($Page > $TotalPages) do={ :set Page $TotalPages; }

  :local StartIdx (($Page - 1) * $PageSize);
  :local EndIdx ($StartIdx + $PageSize);
  :if ($EndIdx > $TotalUsers) do={ :set EndIdx $TotalUsers; }

  :local Msg "*Active Hotspot Users*\n";
  :set Msg ($Msg . "Total: " . $TotalUsers . " | Page " . $Page . "/" . $TotalPages . "\n\n");

  :if ($TotalUsers = 0) do={
    :set Msg ($Msg . "_No active users_");
    :return ({"message"=$Msg; "page"=$Page; "total_pages"=$TotalPages; "count"=$TotalUsers});
  }

  :local Idx 0;
  :foreach User in=$Users do={
    :if ($Idx >= $StartIdx && $Idx < $EndIdx) do={
      :local Username ($User->"user");
      :local IP ($User->"address");
      :local MAC ($User->"mac-address");
      :local Uptime ($User->"uptime");
      :local BytesIn ($User->"bytes-in");
      :local BytesOut ($User->"bytes-out");

      :if ([:len $Username] = 0) do={ :set Username "Guest"; }

      :set Msg ($Msg . "*" . $Username . "*\n");
      :set Msg ($Msg . "  IP: `" . $IP . "`\n");
      :set Msg ($Msg . "  MAC: `" . $MAC . "`\n");

      :if ([:typeof $Uptime] = "time") do={
        :set Msg ($Msg . "  Uptime: " . [:tostr $Uptime] . "\n");
      }

      # Format bandwidth usage
      :if ([:typeof $BytesIn] = "num" && [:typeof $BytesOut] = "num") do={
        :if ([:typeof $FormatBytes] = "array") do={
          :set Msg ($Msg . "  DL: " . [$FormatBytes $BytesIn] . " | UL: " . [$FormatBytes $BytesOut] . "\n");
        } else={
          :set Msg ($Msg . "  DL: " . ($BytesIn / 1048576) . "MB | UL: " . ($BytesOut / 1048576) . "MB\n");
        }
      }
      :set Msg ($Msg . "\n");
    }
    :set Idx ($Idx + 1);
  }

  :return ({"message"=$Msg; "page"=$Page; "total_pages"=$TotalPages; "count"=$TotalUsers});
}

# ============================================================================
# GET HOTSPOT STATISTICS
# ============================================================================

:global GetHotspotStats do={
  :local Stats ({
    "servers"=0;
    "active_users"=0;
    "total_users"=0;
    "bindings"=0;
    "hosts"=0;
    "ip_bindings"=0
  });

  :onerror Err {
    :set ($Stats->"servers") [:len [/ip hotspot find]];
    :set ($Stats->"active_users") [:len [/ip hotspot active find]];
    :set ($Stats->"total_users") [:len [/ip hotspot user find]];
    :set ($Stats->"hosts") [:len [/ip hotspot host find]];
    :set ($Stats->"ip_bindings") [:len [/ip hotspot ip-binding find]];
  } do={
    :log warning ("[hotspot-monitor] - Error getting stats: " . $Err);
  }

  :return $Stats;
}

# ============================================================================
# FORMAT HOTSPOT STATISTICS
# ============================================================================

:global FormatHotspotStats do={
  :local Stats $1;

  :local Msg "*Hotspot Statistics*\n\n";
  :set Msg ($Msg . "Servers: " . ($Stats->"servers") . "\n");
  :set Msg ($Msg . "Active Users: " . ($Stats->"active_users") . "\n");
  :set Msg ($Msg . "Total Users: " . ($Stats->"total_users") . "\n");
  :set Msg ($Msg . "Connected Hosts: " . ($Stats->"hosts") . "\n");
  :set Msg ($Msg . "IP Bindings: " . ($Stats->"ip_bindings") . "\n");

  :return $Msg;
}

# ============================================================================
# DISCONNECT HOTSPOT USER
# ============================================================================

:global DisconnectHotspotUser do={
  :local Identifier [:tostr $1];  # Can be username, MAC, or IP

  :onerror Err {
    # Try to find by username first
    :local Found [/ip hotspot active find where user=$Identifier];

    # Try MAC address
    :if ([:len $Found] = 0) do={
      :set Found [/ip hotspot active find where mac-address=$Identifier];
    }

    # Try IP address
    :if ([:len $Found] = 0) do={
      :set Found [/ip hotspot active find where address=$Identifier];
    }

    :if ([:len $Found] > 0) do={
      :foreach User in=$Found do={
        :local UserData [/ip hotspot active get $User];
        :local Username ($UserData->"user");
        :local MAC ($UserData->"mac-address");
        /ip hotspot active remove $User;
        :log info ("[hotspot-monitor] - Disconnected user: " . $Username . " (" . $MAC . ")");
      }
      :return ({success=true; count=[:len $Found]; error=""});
    } else={
      :return ({success=false; count=0; error="User not found"});
    }
  } do={
    :return ({success=false; count=0; error=[:tostr $Err]});
  }
}

# ============================================================================
# ADD USER TO HOTSPOT (Create user account)
# ============================================================================

:global AddHotspotUser do={
  :local Username [:tostr $1];
  :local Password [:tostr $2];
  :local Profile [:tostr $3];

  :if ([:len $Username] = 0) do={
    :return ({success=false; error="Username required"});
  }

  :if ([:len $Password] = 0) do={
    :set Password $Username;  # Default password = username
  }

  :if ([:len $Profile] = 0) do={
    :set Profile "default";
  }

  :onerror Err {
    # Check if user already exists
    :local Existing [/ip hotspot user find where name=$Username];
    :if ([:len $Existing] > 0) do={
      :return ({success=false; error="User already exists"});
    }

    /ip hotspot user add name=$Username password=$Password profile=$Profile;
    :log info ("[hotspot-monitor] - Created hotspot user: " . $Username);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# REMOVE HOTSPOT USER
# ============================================================================

:global RemoveHotspotUser do={
  :local Username [:tostr $1];

  :onerror Err {
    :local Found [/ip hotspot user find where name=$Username];
    :if ([:len $Found] > 0) do={
      /ip hotspot user remove $Found;
      :log info ("[hotspot-monitor] - Removed hotspot user: " . $Username);
      :return ({success=true; error=""});
    } else={
      :return ({success=false; error="User not found"});
    }
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# ADD MAC TO WHITELIST (Bypass authentication)
# ============================================================================

:global AddHotspotMacWhitelist do={
  :local MAC [:tostr $1];
  :local Comment [:tostr $2];

  :if ([:len $MAC] < 11) do={
    :return ({success=false; error="Invalid MAC address"});
  }

  :if ([:len $Comment] = 0) do={
    :set Comment ("Added via Telegram " . [/system clock get date]);
  }

  :onerror Err {
    # Check if already exists
    :local Existing [/ip hotspot ip-binding find where mac-address=$MAC];
    :if ([:len $Existing] > 0) do={
      :return ({success=false; error="MAC already in bindings"});
    }

    /ip hotspot ip-binding add mac-address=$MAC type=bypassed comment=$Comment;
    :log info ("[hotspot-monitor] - Added MAC to whitelist: " . $MAC);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# BLOCK MAC ADDRESS
# ============================================================================

:global BlockHotspotMac do={
  :local MAC [:tostr $1];
  :local Comment [:tostr $2];

  :if ([:len $MAC] < 11) do={
    :return ({success=false; error="Invalid MAC address"});
  }

  :if ([:len $Comment] = 0) do={
    :set Comment ("Blocked via Telegram " . [/system clock get date]);
  }

  :onerror Err {
    # Check if already exists
    :local Existing [/ip hotspot ip-binding find where mac-address=$MAC];
    :if ([:len $Existing] > 0) do={
      # Update existing to blocked
      /ip hotspot ip-binding set $Existing type=blocked comment=$Comment;
    } else={
      /ip hotspot ip-binding add mac-address=$MAC type=blocked comment=$Comment;
    }
    :log info ("[hotspot-monitor] - Blocked MAC: " . $MAC);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# UNBLOCK MAC ADDRESS
# ============================================================================

:global UnblockHotspotMac do={
  :local MAC [:tostr $1];

  :onerror Err {
    :local Found [/ip hotspot ip-binding find where mac-address=$MAC];
    :if ([:len $Found] > 0) do={
      /ip hotspot ip-binding remove $Found;
      :log info ("[hotspot-monitor] - Unblocked MAC: " . $MAC);
      :return ({success=true; error=""});
    } else={
      :return ({success=false; error="MAC not found in bindings"});
    }
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# LIST HOTSPOT SERVERS
# ============================================================================

:global GetHotspotServers do={
  :local Servers ({});

  :onerror Err {
    :foreach Server in=[/ip hotspot find] do={
      :local ServerData [/ip hotspot get $Server];
      :local ServerInfo ({
        "id"=[:tostr $Server];
        "name"=($ServerData->"name");
        "interface"=($ServerData->"interface");
        "disabled"=($ServerData->"disabled");
        "profile"=($ServerData->"profile");
        "address-pool"=($ServerData->"address-pool")
      });
      :set ($Servers->[:len $Servers]) $ServerInfo;
    }
  } do={
    :log warning ("[hotspot-monitor] - Error getting servers: " . $Err);
  }

  :return $Servers;
}

# ============================================================================
# GET HOTSPOT PROFILES
# ============================================================================

:global GetHotspotProfiles do={
  :local Profiles ({});

  :onerror Err {
    :foreach Profile in=[/ip hotspot user profile find] do={
      :local ProfileData [/ip hotspot user profile get $Profile];
      :local ProfileInfo ({
        "name"=($ProfileData->"name");
        "rate-limit"=($ProfileData->"rate-limit");
        "session-timeout"=($ProfileData->"session-timeout");
        "idle-timeout"=($ProfileData->"idle-timeout");
        "shared-users"=($ProfileData->"shared-users")
      });
      :set ($Profiles->[:len $Profiles]) $ProfileInfo;
    }
  } do={
    :log warning ("[hotspot-monitor] - Error getting profiles: " . $Err);
  }

  :return $Profiles;
}

# ============================================================================
# SHOW HOTSPOT MENU (Interactive)
# ============================================================================

:global ShowHotspotMenu do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];

  :global IsHotspotAvailable;
  :global GetHotspotStats;
  :global SendTelegramWithKeyboard;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;

  :if ([$IsHotspotAvailable] != true) do={
    :local Msg "*Hotspot*\n\nNo hotspot servers configured on this router\\.";
    :local Buttons ({{
      {text="Back"; callback_data="menu:main"}
    }});
    :local KeyboardJson [$CreateInlineKeyboard $Buttons];

    :if ([:len $MessageId] > 0 && [:typeof $EditTelegramMessage] = "array") do={
      [$EditTelegramMessage $ChatId $MessageId $Msg $KeyboardJson];
    } else={
      [$SendTelegramWithKeyboard $ChatId $Msg $KeyboardJson $ThreadId];
    }
    :return;
  }

  :local Stats [$GetHotspotStats];
  :local Msg "*Hotspot Management*\n\n";
  :set Msg ($Msg . "Active Users: " . ($Stats->"active_users") . "\n");
  :set Msg ($Msg . "Total Users: " . ($Stats->"total_users") . "\n");
  :set Msg ($Msg . "Servers: " . ($Stats->"servers") . "\n");
  :set Msg ($Msg . "\n_Select an option:_");

  :local Buttons ({
    {
      {text="Active Users"; callback_data="hotspot:active:1"};
      {text="Stats"; callback_data="hotspot:stats"}
    };
    {
      {text="Add User"; callback_data="hotspot:add"};
      {text="Kick User"; callback_data="hotspot:kick"}
    };
    {
      {text="Whitelist MAC"; callback_data="hotspot:whitelist"};
      {text="Block MAC"; callback_data="hotspot:block"}
    };
    {
      {text="Back"; callback_data="menu:main"}
    }
  });

  :local KeyboardJson [$CreateInlineKeyboard $Buttons];

  :if ([:len $MessageId] > 0 && [:typeof $EditTelegramMessage] = "array") do={
    [$EditTelegramMessage $ChatId $MessageId $Msg $KeyboardJson];
  } else={
    [$SendTelegramWithKeyboard $ChatId $Msg $KeyboardJson $ThreadId];
  }
}

# ============================================================================
# HANDLE HOTSPOT CALLBACKS
# ============================================================================

:global HandleHotspotCallback do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local Data [:tostr $3];
  :local ThreadId [:tostr $4];

  :global GetHotspotActiveUsers;
  :global FormatHotspotUsers;
  :global GetHotspotStats;
  :global FormatHotspotStats;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;
  :global AnswerCallbackQuery;

  # Parse action from callback data (format: hotspot:<action>:<param>)
  :local Action "";
  :local Param "";
  :local ColonPos [:find $Data ":" 8];  # Find colon after "hotspot:"
  :if ([:typeof $ColonPos] = "num") do={
    :set Action [:pick $Data 8 $ColonPos];
    :set Param [:pick $Data ($ColonPos + 1) [:len $Data]];
  } else={
    :set Action [:pick $Data 8 [:len $Data]];
  }

  :local ResponseMsg "";
  :local Buttons ({});

  # Show active users with pagination
  :if ($Action = "active") do={
    :local Page [:tonum $Param];
    :if ([:typeof $Page] != "num" || $Page < 1) do={ :set Page 1; }

    :local Users [$GetHotspotActiveUsers];
    :local Formatted [$FormatHotspotUsers $Users $Page];
    :set ResponseMsg ($Formatted->"message");

    :local TotalPages ($Formatted->"total_pages");
    :local CurrentPage ($Formatted->"page");

    # Build pagination buttons
    :local NavRow ({});
    :if ($CurrentPage > 1) do={
      :set ($NavRow->[:len $NavRow]) {text="< Prev"; callback_data=("hotspot:active:" . ($CurrentPage - 1))};
    }
    :set ($NavRow->[:len $NavRow]) {text="Refresh"; callback_data=("hotspot:active:" . $CurrentPage)};
    :if ($CurrentPage < $TotalPages) do={
      :set ($NavRow->[:len $NavRow]) {text="Next >"; callback_data=("hotspot:active:" . ($CurrentPage + 1))};
    }

    :set Buttons ({
      $NavRow;
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Show statistics
  :if ($Action = "stats") do={
    :local Stats [$GetHotspotStats];
    :set ResponseMsg [$FormatHotspotStats $Stats];
    :set Buttons ({
      {{text="Refresh"; callback_data="hotspot:stats"}};
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Show add user prompt
  :if ($Action = "add") do={
    :set ResponseMsg ("*Add Hotspot User*\n\n" . \
      "Use command:\n" . \
      "`/hotspot add <username> <password> [profile]`\n\n" . \
      "Example:\n" . \
      "`/hotspot add guest1 guest123 default`");
    :set Buttons ({
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Show kick user prompt
  :if ($Action = "kick") do={
    :set ResponseMsg ("*Disconnect User*\n\n" . \
      "Use command:\n" . \
      "`/hotspot kick <user|mac|ip>`\n\n" . \
      "Example:\n" . \
      "`/hotspot kick guest1`\n" . \
      "`/hotspot kick AA:BB:CC:DD:EE:FF`");
    :set Buttons ({
      {{text="Active Users"; callback_data="hotspot:active:1"}};
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Show whitelist prompt
  :if ($Action = "whitelist") do={
    :set ResponseMsg ("*Whitelist MAC Address*\n\n" . \
      "Bypass hotspot authentication for a MAC:\n\n" . \
      "`/hotspot whitelist <MAC> [comment]`\n\n" . \
      "Example:\n" . \
      "`/hotspot whitelist AA:BB:CC:DD:EE:FF Staff PC`");
    :set Buttons ({
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Show block prompt
  :if ($Action = "block") do={
    :set ResponseMsg ("*Block MAC Address*\n\n" . \
      "Block a device from accessing hotspot:\n\n" . \
      "`/hotspot block <MAC> [reason]`\n\n" . \
      "To unblock:\n" . \
      "`/hotspot unblock <MAC>`");
    :set Buttons ({
      {{text="Back"; callback_data="hotspot:menu"}}
    });
  }

  # Return to hotspot menu
  :if ($Action = "menu") do={
    :global ShowHotspotMenu;
    [$ShowHotspotMenu $ChatId $MessageId $ThreadId];
    :return;
  }

  # Send response
  :if ([:len $ResponseMsg] > 0) do={
    :local KeyboardJson [$CreateInlineKeyboard $Buttons];
    [$EditTelegramMessage $ChatId $MessageId $ResponseMsg $KeyboardJson];
  }
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:set HotspotMonitorLoaded true;
:log info "Hotspot monitor module loaded"
