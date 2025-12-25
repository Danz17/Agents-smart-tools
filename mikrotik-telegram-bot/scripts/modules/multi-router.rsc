#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Multi-Router Management Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Manages multiple MikroTik routers through Python relay service
# Dependencies: shared-functions, telegram-api

# ============================================================================
# LOADING GUARD
# ============================================================================

:global MultiRouterLoaded;
:if ($MultiRouterLoaded = true) do={
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
    :log error ("[multi-router] - Failed to load shared-functions: " . $LoadErr);
    :return;
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global ParseJSON;
:global TelegramChatId;

# ============================================================================
# CONFIGURATION
# ============================================================================

:global MultiRouterEnabled;
:global MultiRouterRelayURL;
:global MultiRouterApiToken;
:global MultiRouterTimeout;
:global DefaultRouter;
:global ActiveRouter;

:if ([:typeof $MultiRouterEnabled] != "bool") do={ :set MultiRouterEnabled false; }
:if ([:typeof $MultiRouterRelayURL] != "str") do={ :set MultiRouterRelayURL "http://192.168.1.100:5001"; }
:if ([:typeof $MultiRouterApiToken] != "str") do={ :set MultiRouterApiToken ""; }
:if ([:typeof $MultiRouterTimeout] != "time") do={ :set MultiRouterTimeout 15s; }
:if ([:typeof $DefaultRouter] != "str") do={ :set DefaultRouter "local"; }
:if ([:typeof $ActiveRouter] != "str") do={ :set ActiveRouter $DefaultRouter; }

# ============================================================================
# HTTP REQUEST TO RELAY
# ============================================================================

:global RelayRequest do={
  :local Endpoint [:tostr $1];
  :local Method [:tostr $2];
  :local Body [:tostr $3];

  :global MultiRouterRelayURL;
  :global MultiRouterApiToken;
  :global MultiRouterTimeout;

  :local URL ($MultiRouterRelayURL . $Endpoint);
  :local Result "";

  :onerror Err {
    :local Headers "";
    :if ([:len $MultiRouterApiToken] > 0) do={
      :set Headers ("Authorization: Bearer " . $MultiRouterApiToken);
    }

    :if ($Method = "GET") do={
      :set Result [/tool fetch url=$URL mode=https \
        http-method=get \
        http-header-field=$Headers \
        output=user as-value duration=$MultiRouterTimeout];
    } else={
      :if ($Method = "POST") do={
        :set Result [/tool fetch url=$URL mode=https \
          http-method=post \
          http-header-field=($Headers . ",Content-Type: application/json") \
          http-data=$Body \
          output=user as-value duration=$MultiRouterTimeout];
      } else={
        :if ($Method = "DELETE") do={
          :set Result [/tool fetch url=$URL mode=https \
            http-method=delete \
            http-header-field=$Headers \
            output=user as-value duration=$MultiRouterTimeout];
        }
      }
    }

    :return ($Result->"data");
  } do={
    :log warning ("[multi-router] - Relay request failed: " . $Err);
    :return "";
  }
}

# ============================================================================
# LIST ROUTERS
# ============================================================================

:global ListRouters do={
  :global RelayRequest;
  :global ParseJSON;

  :local Response [$RelayRequest "/routers" "GET" ""];
  :if ([:len $Response] = 0) do={
    :return ({});
  }

  :onerror Err {
    :local Data [$ParseJSON $Response];
    :if (($Data->"success") = true) do={
      :return ($Data->"routers");
    }
  } do={
    :log warning ("[multi-router] - Failed to parse router list");
  }

  :return ({});
}

# ============================================================================
# GET ROUTER STATUS
# ============================================================================

:global GetRouterStatus do={
  :local RouterName [:tostr $1];
  :global RelayRequest;
  :global ParseJSON;

  :local Response [$RelayRequest ("/routers/" . $RouterName . "/status") "GET" ""];
  :if ([:len $Response] = 0) do={
    :return ({success=false; error="No response from relay"});
  }

  :onerror Err {
    :return [$ParseJSON $Response];
  } do={
    :return ({success=false; error="Failed to parse response"});
  }
}

# ============================================================================
# EXECUTE REMOTE COMMAND
# ============================================================================

:global ExecuteRemoteCommand do={
  :local RouterName [:tostr $1];
  :local Command [:tostr $2];
  :local Args $3;

  :global RelayRequest;
  :global ParseJSON;
  :global ActiveRouter;

  # Use active router if not specified
  :if ([:len $RouterName] = 0) do={
    :set RouterName $ActiveRouter;
  }

  # Handle "local" as special case
  :if ($RouterName = "local") do={
    :return ({
      success=false;
      error="Use local commands directly, not via relay"
    });
  }

  # Build request body
  :local Body "{\"command\":\"";
  :set Body ($Body . $Command . "\"");

  :if ([:typeof $Args] = "array") do={
    :set Body ($Body . ",\"args\":{");
    :local First true;
    :foreach K,V in=$Args do={
      :if ($First = false) do={
        :set Body ($Body . ",");
      }
      :set Body ($Body . "\"" . $K . "\":\"" . $V . "\"");
      :set First false;
    }
    :set Body ($Body . "}");
  }

  :set Body ($Body . "}");

  :local Response [$RelayRequest ("/routers/" . $RouterName . "/execute") "POST" $Body];
  :if ([:len $Response] = 0) do={
    :return ({success=false; error="No response from relay"});
  }

  :onerror Err {
    :return [$ParseJSON $Response];
  } do={
    :return ({success=false; error="Failed to parse response"});
  }
}

# ============================================================================
# REGISTER ROUTER
# ============================================================================

:global RegisterRouter do={
  :local RouterName [:tostr $1];
  :local Host [:tostr $2];
  :local Username [:tostr $3];
  :local Password [:tostr $4];
  :local Port [:tonum $5];
  :local Description [:tostr $6];

  :global RelayRequest;
  :global ParseJSON;

  :if ([:len $Port] = 0 || $Port = 0) do={
    :set Port 8728;
  }

  :local Body "{\"name\":\"";
  :set Body ($Body . $RouterName . "\",");
  :set Body ($Body . "\"host\":\"" . $Host . "\",");
  :set Body ($Body . "\"username\":\"" . $Username . "\",");
  :set Body ($Body . "\"password\":\"" . $Password . "\",");
  :set Body ($Body . "\"port\":" . $Port);

  :if ([:len $Description] > 0) do={
    :set Body ($Body . ",\"description\":\"" . $Description . "\"");
  }

  :set Body ($Body . "}");

  :local Response [$RelayRequest "/routers" "POST" $Body];
  :if ([:len $Response] = 0) do={
    :return ({success=false; error="No response from relay"});
  }

  :onerror Err {
    :return [$ParseJSON $Response];
  } do={
    :return ({success=false; error="Failed to parse response"});
  }
}

# ============================================================================
# REMOVE ROUTER
# ============================================================================

:global RemoveRouter do={
  :local RouterName [:tostr $1];
  :global RelayRequest;
  :global ParseJSON;
  :global ActiveRouter;
  :global DefaultRouter;

  :local Response [$RelayRequest ("/routers/" . $RouterName) "DELETE" ""];
  :if ([:len $Response] = 0) do={
    :return ({success=false; error="No response from relay"});
  }

  # Reset active router if we removed it
  :if ($ActiveRouter = $RouterName) do={
    :set ActiveRouter $DefaultRouter;
  }

  :onerror Err {
    :return [$ParseJSON $Response];
  } do={
    :return ({success=false; error="Failed to parse response"});
  }
}

# ============================================================================
# SWITCH ACTIVE ROUTER
# ============================================================================

:global SwitchActiveRouter do={
  :local RouterName [:tostr $1];
  :global ActiveRouter;
  :global DefaultRouter;

  :if ($RouterName = "local") do={
    :set ActiveRouter "local";
    :return ({success=true; router="local"; message="Switched to local router"});
  }

  # Verify router exists
  :global GetRouterStatus;
  :local Status [$GetRouterStatus $RouterName];

  :if (($Status->"success") != true) do={
    :return ({
      success=false;
      error=("Router '" . $RouterName . "' not found or offline")
    });
  }

  :set ActiveRouter $RouterName;
  :return ({
    success=true;
    router=$RouterName;
    message=("Switched to: " . $RouterName)
  });
}

# ============================================================================
# GET ALL ROUTER STATUSES
# ============================================================================

:global GetAllRouterStatuses do={
  :global RelayRequest;
  :global ParseJSON;

  :local Response [$RelayRequest "/routers/all/status" "GET" ""];
  :if ([:len $Response] = 0) do={
    :return ({success=false; error="No response from relay"});
  }

  :onerror Err {
    :return [$ParseJSON $Response];
  } do={
    :return ({success=false; error="Failed to parse response"});
  }
}

# ============================================================================
# FORMAT ROUTER LIST MESSAGE
# ============================================================================

:global FormatRouterList do={
  :global ListRouters;
  :global ActiveRouter;
  :global Identity;

  :local Routers [$ListRouters];
  :local Msg "🌐 *Router Fleet*\n\n";

  # Show local router first
  :local LocalStatus "✅";
  :local LocalActive "";
  :if ($ActiveRouter = "local") do={
    :set LocalActive " 🔹";
  }

  :set Msg ($Msg . $LocalStatus . " *local* (" . $Identity . ")" . $LocalActive . "\n");
  :set Msg ($Msg . "   `This device`\n\n");

  # Show remote routers
  :if ([:len $Routers] = 0) do={
    :set Msg ($Msg . "_No remote routers registered_\n");
    :set Msg ($Msg . "_Use `/routers add` to add one_");
  } else={
    :foreach Router in=$Routers do={
      :local Name ($Router->"name");
      :local Host ($Router->"host");
      :local Online ($Router->"online");
      :local Desc ($Router->"description");

      :local Status "❌";
      :if ($Online = true) do={
        :set Status "✅";
      }

      :local Active "";
      :if ($ActiveRouter = $Name) do={
        :set Active " 🔹";
      }

      :set Msg ($Msg . $Status . " *" . $Name . "*" . $Active . "\n");
      :set Msg ($Msg . "   `" . $Host . "`");
      :if ([:len $Desc] > 0) do={
        :set Msg ($Msg . " - " . $Desc);
      }
      :set Msg ($Msg . "\n\n");
    }
  }

  :set Msg ($Msg . "───────────────\n");
  :set Msg ($Msg . "Active: *" . $ActiveRouter . "*");

  :return $Msg;
}

# ============================================================================
# FORMAT ROUTER STATUS MESSAGE
# ============================================================================

:global FormatRouterStatus do={
  :local Status $1;
  :local Msg "";

  :if (($Status->"success") != true) do={
    :set Msg ("❌ *Router Offline*\n\n");
    :set Msg ($Msg . "Error: `" . ($Status->"error") . "`");
    :return $Msg;
  }

  :local RouterName ($Status->"router");
  :local Identity ($Status->"identity");
  :local Version ($Status->"version");
  :local Uptime ($Status->"uptime");
  :local CPULoad ($Status->"cpu_load");
  :local MemUsed ($Status->"memory_used");

  :set Msg ("✅ *" . $RouterName . "* - Online\n\n");
  :set Msg ($Msg . "📛 Identity: `" . $Identity . "`\n");
  :set Msg ($Msg . "📦 RouterOS: `" . $Version . "`\n");
  :set Msg ($Msg . "⏱️ Uptime: `" . $Uptime . "`\n");
  :set Msg ($Msg . "🔥 CPU: `" . $CPULoad . "`\n");
  :set Msg ($Msg . "💾 RAM: `" . $MemUsed . "`");

  :return $Msg;
}

# ============================================================================
# SHOW ROUTERS MENU
# ============================================================================

:global ShowRoutersMenu do={
  :global SendTelegram2;
  :global TelegramChatId;
  :global FormatRouterList;
  :global ListRouters;
  :global ActiveRouter;

  :local Routers [$ListRouters];
  :local Msg [$FormatRouterList];

  # Build inline keyboard
  :local Buttons ({});

  # Local router button
  :local LocalLabel "📍 Local";
  :if ($ActiveRouter = "local") do={
    :set LocalLabel "📍 Local ✓";
  }
  :set ($Buttons->[:len $Buttons]) ({{text=$LocalLabel; callback_data="router:switch:local"}});

  # Remote router buttons (max 3 per row)
  :local Row ({});
  :foreach Router in=$Routers do={
    :local Name ($Router->"name");
    :local Online ($Router->"online");

    :local Icon "🔴";
    :if ($Online = true) do={
      :set Icon "🟢";
    }

    :local Label ($Icon . " " . $Name);
    :if ($ActiveRouter = $Name) do={
      :set Label ($Label . " ✓");
    }

    :set ($Row->[:len $Row]) ({text=$Label; callback_data=("router:switch:" . $Name)});

    :if ([:len $Row] >= 2) do={
      :set ($Buttons->[:len $Buttons]) $Row;
      :set Row ({});
    }
  }

  :if ([:len $Row] > 0) do={
    :set ($Buttons->[:len $Buttons]) $Row;
  }

  # Action buttons
  :set ($Buttons->[:len $Buttons]) ({
    {text="📊 Status All"; callback_data="router:status-all"};
    {text="➕ Add Router"; callback_data="router:add-prompt"}
  });

  :set ($Buttons->[:len $Buttons]) ({
    {text="🔄 Refresh"; callback_data="router:refresh"};
    {text="◀️ Back"; callback_data="menu:main"}
  });

  $SendTelegram2 ({
    chatid=$TelegramChatId;
    subject="🌐 Router Management";
    message=$Msg;
    keyboard=$Buttons
  });
}

# ============================================================================
# HANDLE ROUTER CALLBACKS
# ============================================================================

:global HandleRouterCallback do={
  :local Action [:tostr $1];
  :local Param [:tostr $2];
  :local CallbackId [:tostr $3];

  :global SendTelegram2;
  :global TelegramChatId;
  :global ShowRoutersMenu;
  :global SwitchActiveRouter;
  :global GetRouterStatus;
  :global GetAllRouterStatuses;
  :global FormatRouterStatus;

  :if ($Action = "switch") do={
    :local Result [$SwitchActiveRouter $Param];
    :if (($Result->"success") = true) do={
      # Refresh menu to show new selection
      [$ShowRoutersMenu];
    } else={
      $SendTelegram2 ({
        chatid=$TelegramChatId;
        subject="❌ Switch Failed";
        message=($Result->"error")
      });
    }
    :return;
  }

  :if ($Action = "status") do={
    :local Status [$GetRouterStatus $Param];
    :local Msg [$FormatRouterStatus $Status];

    :local Buttons ({});
    :set ($Buttons->[:len $Buttons]) ({
      {text="🔄 Refresh"; callback_data=("router:status:" . $Param)};
      {text="◀️ Back"; callback_data="menu:routers"}
    });

    $SendTelegram2 ({
      chatid=$TelegramChatId;
      subject=("📊 " . $Param);
      message=$Msg;
      keyboard=$Buttons
    });
    :return;
  }

  :if ($Action = "status-all") do={
    :local AllStatus [$GetAllRouterStatuses];

    :local Msg "📊 *All Router Status*\n\n";

    :if (($AllStatus->"success") = true) do={
      :set Msg ($Msg . "🟢 Online: " . ($AllStatus->"online") . "\n");
      :set Msg ($Msg . "🔴 Offline: " . ($AllStatus->"offline") . "\n\n");

      :foreach Router in=($AllStatus->"routers") do={
        :local Name ($Router->"router");
        :local Online ($Router->"online");

        :if ($Online = true) do={
          :set Msg ($Msg . "✅ *" . $Name . "*\n");
          :set Msg ($Msg . "   CPU: `" . ($Router->"cpu_load") . "` | ");
          :set Msg ($Msg . "RAM: `" . ($Router->"memory_used") . "`\n");
        } else={
          :set Msg ($Msg . "❌ *" . $Name . "* - Offline\n");
        }
      }
    } else={
      :set Msg ($Msg . "❌ Failed to get status\n");
      :set Msg ($Msg . ($AllStatus->"error"));
    }

    :local Buttons ({});
    :set ($Buttons->[:len $Buttons]) ({
      {text="🔄 Refresh"; callback_data="router:status-all"};
      {text="◀️ Back"; callback_data="menu:routers"}
    });

    $SendTelegram2 ({
      chatid=$TelegramChatId;
      subject="📊 Fleet Status";
      message=$Msg;
      keyboard=$Buttons
    });
    :return;
  }

  :if ($Action = "add-prompt") do={
    :local Msg "➕ *Add New Router*\n\n";
    :set Msg ($Msg . "Use the command:\n\n");
    :set Msg ($Msg . "`/routers add <name> <host> <user> <pass>`\n\n");
    :set Msg ($Msg . "Example:\n");
    :set Msg ($Msg . "`/routers add office 192.168.1.1 admin secret`\n\n");
    :set Msg ($Msg . "Optional port (default 8728):\n");
    :set Msg ($Msg . "`/routers add office 192.168.1.1 admin secret 8729`");

    :local Buttons ({});
    :set ($Buttons->[:len $Buttons]) ({
      {text="◀️ Back"; callback_data="menu:routers"}
    });

    $SendTelegram2 ({
      chatid=$TelegramChatId;
      subject="➕ Add Router";
      message=$Msg;
      keyboard=$Buttons
    });
    :return;
  }

  :if ($Action = "refresh") do={
    [$ShowRoutersMenu];
    :return;
  }

  :if ($Action = "remove") do={
    :global RemoveRouter;
    :local Result [$RemoveRouter $Param];

    :if (($Result->"success") = true) do={
      $SendTelegram2 ({
        chatid=$TelegramChatId;
        subject="✅ Router Removed";
        message=("Removed: *" . $Param . "*")
      });
      [$ShowRoutersMenu];
    } else={
      $SendTelegram2 ({
        chatid=$TelegramChatId;
        subject="❌ Remove Failed";
        message=($Result->"error")
      });
    }
    :return;
  }
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:set MultiRouterLoaded true;
:log info "Multi-router module loaded"
