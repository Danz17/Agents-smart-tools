#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Bridge & VLAN Control Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# L2 Bridge and VLAN management via Telegram
# Dependencies: shared-functions, telegram-api

# ============================================================================
# LOADING GUARD
# ============================================================================

:global BridgeVlanLoaded;
:if ($BridgeVlanLoaded = true) do={
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
    :log error "[bridge-vlan] - Failed to load shared-functions";
    :return;
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/telegram-api";
  } do={
    :log warning "[bridge-vlan] - Telegram API not available";
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global TelegramChatId;
:global TelegramThreadId;

# ============================================================================
# LIST BRIDGES
# ============================================================================

:global GetBridges do={
  :local Bridges ({});

  :onerror Err {
    :foreach Bridge in=[/interface bridge find] do={
      :local BridgeData [/interface bridge get $Bridge];
      :local BridgeInfo ({
        "id"=[:tostr $Bridge];
        "name"=($BridgeData->"name");
        "disabled"=($BridgeData->"disabled");
        "running"=($BridgeData->"running");
        "mtu"=($BridgeData->"mtu");
        "protocol-mode"=($BridgeData->"protocol-mode");
        "vlan-filtering"=($BridgeData->"vlan-filtering");
        "pvid"=($BridgeData->"pvid");
        "mac-address"=($BridgeData->"mac-address")
      });
      :set ($Bridges->[:len $Bridges]) $BridgeInfo;
    }
  } do={
    :log warning ("[bridge-vlan] - Error getting bridges: " . $Err);
  }

  :return $Bridges;
}

# ============================================================================
# FORMAT BRIDGES LIST
# ============================================================================

:global FormatBridges do={
  :local Bridges $1;

  :local Msg "*Bridges*\n\n";

  :if ([:len $Bridges] = 0) do={
    :set Msg ($Msg . "_No bridges configured_");
    :return $Msg;
  }

  :foreach Bridge in=$Bridges do={
    :local Name ($Bridge->"name");
    :local Running ($Bridge->"running");
    :local Disabled ($Bridge->"disabled");
    :local VlanFilter ($Bridge->"vlan-filtering");

    :local Status "";
    :if ($Disabled = true) do={
      :set Status "Disabled";
    } else={
      :if ($Running = true) do={
        :set Status "Running";
      } else={
        :set Status "Down";
      }
    }

    :set Msg ($Msg . "*" . $Name . "*\n");
    :set Msg ($Msg . "  Status: " . $Status . "\n");
    :set Msg ($Msg . "  VLAN Filtering: " . [:tostr $VlanFilter] . "\n");
    :if ([:typeof ($Bridge->"pvid")] = "num") do={
      :set Msg ($Msg . "  PVID: " . ($Bridge->"pvid") . "\n");
    }
    :set Msg ($Msg . "\n");
  }

  :return $Msg;
}

# ============================================================================
# GET BRIDGE PORTS
# ============================================================================

:global GetBridgePorts do={
  :local BridgeName [:tostr $1];
  :local Ports ({});

  :onerror Err {
    :local Filter;
    :if ([:len $BridgeName] > 0) do={
      :set Filter [/interface bridge port find where bridge=$BridgeName];
    } else={
      :set Filter [/interface bridge port find];
    }

    :foreach Port in=$Filter do={
      :local PortData [/interface bridge port get $Port];
      :local PortInfo ({
        "id"=[:tostr $Port];
        "interface"=($PortData->"interface");
        "bridge"=($PortData->"bridge");
        "disabled"=($PortData->"disabled");
        "pvid"=($PortData->"pvid");
        "hw"=($PortData->"hw");
        "frame-types"=($PortData->"frame-types")
      });
      :set ($Ports->[:len $Ports]) $PortInfo;
    }
  } do={
    :log warning ("[bridge-vlan] - Error getting ports: " . $Err);
  }

  :return $Ports;
}

# ============================================================================
# FORMAT BRIDGE PORTS
# ============================================================================

:global FormatBridgePorts do={
  :local Ports $1;
  :local BridgeName [:tostr $2];

  :local Msg "";
  :if ([:len $BridgeName] > 0) do={
    :set Msg ("*Bridge Ports: " . $BridgeName . "*\n\n");
  } else={
    :set Msg "*All Bridge Ports*\n\n";
  }

  :if ([:len $Ports] = 0) do={
    :set Msg ($Msg . "_No ports configured_");
    :return $Msg;
  }

  :foreach Port in=$Ports do={
    :local Interface ($Port->"interface");
    :local Bridge ($Port->"bridge");
    :local Disabled ($Port->"disabled");
    :local PVID ($Port->"pvid");

    :local Status "";
    :if ($Disabled = true) do={
      :set Status " (Disabled)";
    }

    :set Msg ($Msg . "• `" . $Interface . "`" . $Status . "\n");
    :if ([:len $BridgeName] = 0) do={
      :set Msg ($Msg . "  Bridge: " . $Bridge . "\n");
    }
    :if ([:typeof $PVID] = "num") do={
      :set Msg ($Msg . "  PVID: " . $PVID . "\n");
    }
  }

  :return $Msg;
}

# ============================================================================
# GET VLANS
# ============================================================================

:global GetBridgeVlans do={
  :local BridgeName [:tostr $1];
  :local Vlans ({});

  :onerror Err {
    :local Filter;
    :if ([:len $BridgeName] > 0) do={
      :set Filter [/interface bridge vlan find where bridge=$BridgeName];
    } else={
      :set Filter [/interface bridge vlan find];
    }

    :foreach Vlan in=$Filter do={
      :local VlanData [/interface bridge vlan get $Vlan];
      :local VlanInfo ({
        "id"=[:tostr $Vlan];
        "bridge"=($VlanData->"bridge");
        "vlan-ids"=($VlanData->"vlan-ids");
        "tagged"=($VlanData->"tagged");
        "untagged"=($VlanData->"untagged");
        "disabled"=($VlanData->"disabled")
      });
      :set ($Vlans->[:len $Vlans]) $VlanInfo;
    }
  } do={
    :log warning ("[bridge-vlan] - Error getting VLANs: " . $Err);
  }

  :return $Vlans;
}

# ============================================================================
# FORMAT VLANS LIST
# ============================================================================

:global FormatBridgeVlans do={
  :local Vlans $1;
  :local BridgeName [:tostr $2];

  :local Msg "";
  :if ([:len $BridgeName] > 0) do={
    :set Msg ("*VLANs: " . $BridgeName . "*\n\n");
  } else={
    :set Msg "*Bridge VLANs*\n\n";
  }

  :if ([:len $Vlans] = 0) do={
    :set Msg ($Msg . "_No VLANs configured_");
    :return $Msg;
  }

  :foreach Vlan in=$Vlans do={
    :local VlanIds ($Vlan->"vlan-ids");
    :local Bridge ($Vlan->"bridge");
    :local Tagged ($Vlan->"tagged");
    :local Untagged ($Vlan->"untagged");
    :local Disabled ($Vlan->"disabled");

    :local Status "";
    :if ($Disabled = true) do={
      :set Status " (Disabled)";
    }

    :set Msg ($Msg . "*VLAN " . [:tostr $VlanIds] . "*" . $Status . "\n");
    :if ([:len $BridgeName] = 0) do={
      :set Msg ($Msg . "  Bridge: " . $Bridge . "\n");
    }
    :if ([:len $Tagged] > 0) do={
      :set Msg ($Msg . "  Tagged: " . [:tostr $Tagged] . "\n");
    }
    :if ([:len $Untagged] > 0) do={
      :set Msg ($Msg . "  Untagged: " . [:tostr $Untagged] . "\n");
    }
    :set Msg ($Msg . "\n");
  }

  :return $Msg;
}

# ============================================================================
# ENABLE/DISABLE VLAN FILTERING
# ============================================================================

:global SetVlanFiltering do={
  :local BridgeName [:tostr $1];
  :local Enable [:tobool $2];

  :onerror Err {
    :local Found [/interface bridge find where name=$BridgeName];
    :if ([:len $Found] = 0) do={
      :return ({success=false; error="Bridge not found"});
    }

    /interface bridge set $Found vlan-filtering=$Enable;
    :local State "disabled";
    :if ($Enable = true) do={ :set State "enabled"; }
    :log info ("[bridge-vlan] - VLAN filtering " . $State . " on " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# ADD VLAN TO BRIDGE
# ============================================================================

:global AddBridgeVlan do={
  :local BridgeName [:tostr $1];
  :local VlanId [:tonum $2];
  :local TaggedPorts $3;
  :local UntaggedPorts $4;

  :if ([:len $BridgeName] = 0) do={
    :return ({success=false; error="Bridge name required"});
  }

  :if ([:typeof $VlanId] != "num" || $VlanId < 1 || $VlanId > 4094) do={
    :return ({success=false; error="Invalid VLAN ID (1-4094)"});
  }

  :onerror Err {
    # Check if bridge exists
    :local BridgeFound [/interface bridge find where name=$BridgeName];
    :if ([:len $BridgeFound] = 0) do={
      :return ({success=false; error="Bridge not found"});
    }

    # Check if VLAN already exists
    :local VlanExists [/interface bridge vlan find where bridge=$BridgeName vlan-ids=$VlanId];
    :if ([:len $VlanExists] > 0) do={
      :return ({success=false; error="VLAN already exists on this bridge"});
    }

    # Build command based on provided ports
    :if ([:len $TaggedPorts] > 0 && [:len $UntaggedPorts] > 0) do={
      /interface bridge vlan add bridge=$BridgeName vlan-ids=$VlanId tagged=$TaggedPorts untagged=$UntaggedPorts;
    } else={
      :if ([:len $TaggedPorts] > 0) do={
        /interface bridge vlan add bridge=$BridgeName vlan-ids=$VlanId tagged=$TaggedPorts;
      } else={
        :if ([:len $UntaggedPorts] > 0) do={
          /interface bridge vlan add bridge=$BridgeName vlan-ids=$VlanId untagged=$UntaggedPorts;
        } else={
          /interface bridge vlan add bridge=$BridgeName vlan-ids=$VlanId tagged=$BridgeName;
        }
      }
    }

    :log info ("[bridge-vlan] - Added VLAN " . $VlanId . " to bridge " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# REMOVE VLAN FROM BRIDGE
# ============================================================================

:global RemoveBridgeVlan do={
  :local BridgeName [:tostr $1];
  :local VlanId [:tonum $2];

  :onerror Err {
    :local Found [/interface bridge vlan find where bridge=$BridgeName vlan-ids=$VlanId];
    :if ([:len $Found] = 0) do={
      :return ({success=false; error="VLAN not found on this bridge"});
    }

    /interface bridge vlan remove $Found;
    :log info ("[bridge-vlan] - Removed VLAN " . $VlanId . " from bridge " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# SET PORT PVID
# ============================================================================

:global SetPortPvid do={
  :local InterfaceName [:tostr $1];
  :local Pvid [:tonum $2];

  :if ([:typeof $Pvid] != "num" || $Pvid < 1 || $Pvid > 4094) do={
    :return ({success=false; error="Invalid PVID (1-4094)"});
  }

  :onerror Err {
    :local Found [/interface bridge port find where interface=$InterfaceName];
    :if ([:len $Found] = 0) do={
      :return ({success=false; error="Port not found in any bridge"});
    }

    /interface bridge port set $Found pvid=$Pvid;
    :log info ("[bridge-vlan] - Set PVID " . $Pvid . " on port " . $InterfaceName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# ADD PORT TO BRIDGE
# ============================================================================

:global AddBridgePort do={
  :local BridgeName [:tostr $1];
  :local InterfaceName [:tostr $2];
  :local Pvid [:tonum $3];

  :if ([:len $InterfaceName] = 0) do={
    :return ({success=false; error="Interface name required"});
  }

  :onerror Err {
    # Check if bridge exists
    :local BridgeFound [/interface bridge find where name=$BridgeName];
    :if ([:len $BridgeFound] = 0) do={
      :return ({success=false; error="Bridge not found"});
    }

    # Check if interface exists
    :local IntFound [/interface find where name=$InterfaceName];
    :if ([:len $IntFound] = 0) do={
      :return ({success=false; error="Interface not found"});
    }

    # Check if already in a bridge
    :local AlreadyPort [/interface bridge port find where interface=$InterfaceName];
    :if ([:len $AlreadyPort] > 0) do={
      :return ({success=false; error="Interface already in a bridge"});
    }

    :if ([:typeof $Pvid] = "num" && $Pvid >= 1 && $Pvid <= 4094) do={
      /interface bridge port add bridge=$BridgeName interface=$InterfaceName pvid=$Pvid;
    } else={
      /interface bridge port add bridge=$BridgeName interface=$InterfaceName;
    }

    :log info ("[bridge-vlan] - Added port " . $InterfaceName . " to bridge " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# REMOVE PORT FROM BRIDGE
# ============================================================================

:global RemoveBridgePort do={
  :local InterfaceName [:tostr $1];

  :onerror Err {
    :local Found [/interface bridge port find where interface=$InterfaceName];
    :if ([:len $Found] = 0) do={
      :return ({success=false; error="Port not found in any bridge"});
    }

    /interface bridge port remove $Found;
    :log info ("[bridge-vlan] - Removed port " . $InterfaceName . " from bridge");
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# CREATE BRIDGE
# ============================================================================

:global CreateBridge do={
  :local BridgeName [:tostr $1];
  :local VlanFiltering [:tobool $2];

  :if ([:len $BridgeName] = 0) do={
    :return ({success=false; error="Bridge name required"});
  }

  :onerror Err {
    # Check if already exists
    :local Existing [/interface bridge find where name=$BridgeName];
    :if ([:len $Existing] > 0) do={
      :return ({success=false; error="Bridge already exists"});
    }

    :if ($VlanFiltering = true) do={
      /interface bridge add name=$BridgeName vlan-filtering=yes;
    } else={
      /interface bridge add name=$BridgeName;
    }

    :log info ("[bridge-vlan] - Created bridge " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# DELETE BRIDGE
# ============================================================================

:global DeleteBridge do={
  :local BridgeName [:tostr $1];

  :onerror Err {
    :local Found [/interface bridge find where name=$BridgeName];
    :if ([:len $Found] = 0) do={
      :return ({success=false; error="Bridge not found"});
    }

    # Remove all ports first
    :foreach Port in=[/interface bridge port find where bridge=$BridgeName] do={
      /interface bridge port remove $Port;
    }

    # Remove all VLANs
    :foreach Vlan in=[/interface bridge vlan find where bridge=$BridgeName] do={
      /interface bridge vlan remove $Vlan;
    }

    # Remove bridge
    /interface bridge remove $Found;

    :log info ("[bridge-vlan] - Deleted bridge " . $BridgeName);
    :return ({success=true; error=""});
  } do={
    :return ({success=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# SHOW BRIDGE MENU (Interactive)
# ============================================================================

:global ShowBridgeMenu do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];

  :global GetBridges;
  :global SendTelegramWithKeyboard;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;

  :local Bridges [$GetBridges];
  :local BridgeCount [:len $Bridges];

  :local Msg "*Bridge & VLAN Management*\n\n";
  :set Msg ($Msg . "Bridges: " . $BridgeCount . "\n");
  :set Msg ($Msg . "\n_Select an option:_");

  :local Buttons ({
    {
      {text="Bridges"; callback_data="bridge:list"};
      {text="Ports"; callback_data="bridge:ports"}
    };
    {
      {text="VLANs"; callback_data="bridge:vlans"};
      {text="Create Bridge"; callback_data="bridge:create"}
    };
    {
      {text="Add VLAN"; callback_data="bridge:addvlan"};
      {text="Set PVID"; callback_data="bridge:setpvid"}
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
# HANDLE BRIDGE CALLBACKS
# ============================================================================

:global HandleBridgeCallback do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local Data [:tostr $3];
  :local ThreadId [:tostr $4];

  :global GetBridges;
  :global FormatBridges;
  :global GetBridgePorts;
  :global FormatBridgePorts;
  :global GetBridgeVlans;
  :global FormatBridgeVlans;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;

  # Parse action from callback data (format: bridge:<action>:<param>)
  :local Action "";
  :local Param "";
  :local ColonPos [:find $Data ":" 7];  # Find colon after "bridge:"
  :if ([:typeof $ColonPos] = "num") do={
    :set Action [:pick $Data 7 $ColonPos];
    :set Param [:pick $Data ($ColonPos + 1) [:len $Data]];
  } else={
    :set Action [:pick $Data 7 [:len $Data]];
  }

  :local ResponseMsg "";
  :local Buttons ({});

  # List bridges
  :if ($Action = "list") do={
    :local Bridges [$GetBridges];
    :set ResponseMsg [$FormatBridges $Bridges];
    :set Buttons ({
      {{text="Refresh"; callback_data="bridge:list"}};
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # List ports
  :if ($Action = "ports") do={
    :local Ports [$GetBridgePorts ""];
    :set ResponseMsg [$FormatBridgePorts $Ports ""];
    :set Buttons ({
      {{text="Refresh"; callback_data="bridge:ports"}};
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # List VLANs
  :if ($Action = "vlans") do={
    :local Vlans [$GetBridgeVlans ""];
    :set ResponseMsg [$FormatBridgeVlans $Vlans ""];
    :set Buttons ({
      {{text="Refresh"; callback_data="bridge:vlans"}};
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # Create bridge prompt
  :if ($Action = "create") do={
    :set ResponseMsg ("*Create Bridge*\n\n" . \
      "Use command:\n" . \
      "`/bridge create <name> [vlan-filter]`\n\n" . \
      "Examples:\n" . \
      "`/bridge create br-lan`\n" . \
      "`/bridge create br-vlan yes`");
    :set Buttons ({
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # Add VLAN prompt
  :if ($Action = "addvlan") do={
    :set ResponseMsg ("*Add VLAN*\n\n" . \
      "Use command:\n" . \
      "`/bridge vlan add <bridge> <vlan-id> [tagged] [untagged]`\n\n" . \
      "Examples:\n" . \
      "`/bridge vlan add bridge 100`\n" . \
      "`/bridge vlan add bridge 100 ether1,ether2 ether3`");
    :set Buttons ({
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # Set PVID prompt
  :if ($Action = "setpvid") do={
    :set ResponseMsg ("*Set Port PVID*\n\n" . \
      "Use command:\n" . \
      "`/bridge pvid <interface> <pvid>`\n\n" . \
      "Example:\n" . \
      "`/bridge pvid ether3 100`");
    :set Buttons ({
      {{text="Ports"; callback_data="bridge:ports"}};
      {{text="Back"; callback_data="bridge:menu"}}
    });
  }

  # Return to bridge menu
  :if ($Action = "menu") do={
    :global ShowBridgeMenu;
    [$ShowBridgeMenu $ChatId $MessageId $ThreadId];
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

:set BridgeVlanLoaded true;
:log info "Bridge/VLAN module loaded"
