#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Network Commands Module
# Network management commands: /routers, /hotspot, /bridge, /monitor-interfaces
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, multi-router, hotspot-monitor, bridge-vlan
#
# Commands:
#   - /routers : Multi-router management
#   - /hotspot : Hotspot user management
#   - /bridge : Bridge/VLAN configuration
#   - /monitor-interfaces : Interface monitoring
#   - @router : Remote execution shorthand

# Loading guard
:do {
  :global NetworkCommandsLoaded
  :if ($NetworkCommandsLoaded) do={ :return }
} on-error={}

:local ScriptName "network-commands";

# Import required globals
:global SendTelegram2;
:global SendBotReplyWithButtons;
:global CreateCommandButtons;
:global RegisterCommandHandler;

# ============================================================================
# HELPER: Parse Command Parts
# ============================================================================

:global ParseCommandParts do={
  :local Command [:tostr $1];

  :local CmdParts ({});
  :local CurrentPart "";
  :for I from=0 to=([:len $Command] - 1) do={
    :local Char [:pick $Command $I ($I + 1)];
    :if ($Char = " ") do={
      :if ([:len $CurrentPart] > 0) do={
        :set ($CmdParts->[:len $CmdParts]) $CurrentPart;
        :set CurrentPart "";
      }
    } else={
      :set CurrentPart ($CurrentPart . $Char);
    }
  }
  :if ([:len $CurrentPart] > 0) do={ :set ($CmdParts->[:len $CmdParts]) $CurrentPart; }

  :return $CmdParts;
}

# ============================================================================
# COMMAND: /routers
# ============================================================================

:global HandleRouters do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ParseCommandParts;
  :global ListRouters;
  :global RegisterRouter;
  :global UnregisterRouter;
  :global GetRouterStatus;
  :global FormatRouterStatus;
  :global ExecuteRemoteCommand;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;
  :global Identity;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :local CmdParts [$ParseCommandParts $Command];
  :local Action ($CmdParts->1);
  :local ResponseMsg "";

  # /routers or /routers list
  :if ([:len $Action] = 0 || $Action = "list") do={
    :global MultiRouterLoaded;
    :if ($MultiRouterLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/multi-router";
      } do={}
    }

    :if ([:typeof $ListRouters] = "array") do={
      :local Routers [$ListRouters];
      :set ResponseMsg "*Registered Routers:*\n\n";
      :foreach Name,Info in=$Routers do={
        :local Status "offline";
        :if (($Info->"online") = true) do={ :set Status "online"; }
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 *" . $Name . "* - " . $Status . "\n");
      }
      :if ([:len $Routers] = 0) do={
        :set ResponseMsg "No routers registered.\n\nUse `/routers add <name> <host> <user> <pass>` to add one.";
      }
    } else={
      :set ResponseMsg "Multi-router module not loaded.";
    }
  }

  # /routers add <name> <host> <user> <pass> [port]
  :if ($Action = "add") do={
    :local Name ($CmdParts->2);
    :local Host ($CmdParts->3);
    :local User ($CmdParts->4);
    :local Pass ($CmdParts->5);
    :local Port ($CmdParts->6);

    :if ([:len $Name] > 0 && [:len $Host] > 0 && [:len $User] > 0 && [:len $Pass] > 0) do={
      :if ([:len $Port] = 0) do={ :set Port "8728"; }
      :if ([:typeof $RegisterRouter] = "array") do={
        :local Result [$RegisterRouter $Name $Host $User $Pass [:tonum $Port] ""];
        :if (($Result->"success") = true) do={
          :set ResponseMsg ("\E2\9C\85 Router added: *" . $Name . "*\n\nHost: `" . $Host . "`\nPort: `" . $Port . "`");
        } else={
          :set ResponseMsg ("\E2\9D\8C Failed to add router\n\n" . ($Result->"error"));
        }
      } else={
        :set ResponseMsg "RegisterRouter function not available.";
      }
    } else={
      :set ResponseMsg "Usage: `/routers add <name> <host> <user> <pass> [port]`\n\nExample:\n`/routers add office 192.168.1.1 admin secret`";
    }
  }

  # /routers remove <name>
  :if ($Action = "remove") do={
    :local Name ($CmdParts->2);
    :if ([:len $Name] > 0) do={
      :if ([:typeof $UnregisterRouter] = "array") do={
        :local Result [$UnregisterRouter $Name];
        :if (($Result->"success") = true) do={
          :set ResponseMsg ("\E2\9C\85 Router removed: *" . $Name . "*");
        } else={
          :set ResponseMsg ("\E2\9D\8C Failed to remove router: " . ($Result->"error"));
        }
      } else={
        :set ResponseMsg "UnregisterRouter function not available.";
      }
    } else={
      :set ResponseMsg "Usage: `/routers remove <name>`";
    }
  }

  # /routers status <name>
  :if ($Action = "status") do={
    :local Name ($CmdParts->2);
    :if ([:len $Name] = 0 || $Name = "local") do={
      :local Resources [/system resource get];
      :local Version ($Resources->"version");
      :local Uptime ($Resources->"uptime");
      :local CPULoad ($Resources->"cpu-load");
      :local FreeMem ($Resources->"free-memory");
      :local TotalMem ($Resources->"total-memory");
      :local MemPct (100 - (($FreeMem * 100) / $TotalMem));
      :set ResponseMsg ("*local* - Online\n\nIdentity: `" . $Identity . "`\nRouterOS: `" . $Version . "`\nUptime: `" . $Uptime . "`\nCPU: `" . $CPULoad . "%`\nRAM: `" . $MemPct . "%`");
    } else={
      :if ([:typeof $GetRouterStatus] = "array" && [:typeof $FormatRouterStatus] = "array") do={
        :local Status [$GetRouterStatus $Name];
        :set ResponseMsg [$FormatRouterStatus $Status];
      } else={
        :set ResponseMsg "Status functions not available.";
      }
    }
  }

  # /routers exec <name> <command>
  :if ($Action = "exec" || $Action = "run") do={
    :local Name ($CmdParts->2);
    :local RemoteCmd "";
    :for I from=3 to=([:len $CmdParts] - 1) do={
      :if ([:len $RemoteCmd] > 0) do={ :set RemoteCmd ($RemoteCmd . " "); }
      :set RemoteCmd ($RemoteCmd . ($CmdParts->$I));
    }

    :if ([:len $Name] > 0 && [:len $RemoteCmd] > 0) do={
      :if ([:typeof $ExecuteRemoteCommand] = "array") do={
        :local Result [$ExecuteRemoteCommand $Name $RemoteCmd];
        :if (($Result->"success") = true) do={
          :set ResponseMsg ("*" . $Name . "* > `" . $RemoteCmd . "`\n\n```\n" . ($Result->"output") . "\n```");
        } else={
          :set ResponseMsg ("\E2\9D\8C Execution failed: " . ($Result->"error"));
        }
      } else={
        :set ResponseMsg "ExecuteRemoteCommand not available.";
      }
    } else={
      :set ResponseMsg "Usage: `/routers exec <name> <command>`\n\nExample:\n`/routers exec office /interface print`";
    }
  }

  :local RouterCmds ({"/routers"; "/routers add"; "/menu"});
  :local RouterButtons [$CreateCommandButtons $RouterCmds];
  [$SendBotReplyWithButtons $ChatId $ResponseMsg $RouterButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: @router (Remote Execution Shorthand)
# ============================================================================

:global HandleAtRouter do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global MultiRouterLoaded;
  :global ExecuteRemoteCommand;
  :global FormatCommandOutput;
  :global SendTelegram2;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Load multi-router if needed
  :if ($MultiRouterLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/multi-router";
    } do={}
  }

  # Parse @router command
  :local SpacePos [:find $Command " "];
  :local RouterName "";
  :local RemoteCmd "";

  :if ([:typeof $SpacePos] = "num") do={
    :set RouterName [:pick $Command 1 $SpacePos];
    :set RemoteCmd [:pick $Command ($SpacePos + 1) [:len $Command]];
  } else={
    :set RouterName [:pick $Command 1 [:len $Command]];
  }

  :if ([:len $RemoteCmd] = 0) do={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Error";
      message=("Usage: `@" . $RouterName . " <command>`\n\nExample:\n`@office /interface print`")
    });
    :return ({ "handled"=true });
  }

  :if ([:typeof $ExecuteRemoteCommand] = "array") do={
    :local Result [$ExecuteRemoteCommand $RouterName $RemoteCmd];
    :if (($Result->"success") = true) do={
      :local Output ($Result->"output");
      :if ([:typeof $FormatCommandOutput] = "array") do={
        :set Output [$FormatCommandOutput $Output];
      }
      $SendTelegram2 ({
        chatid=$ChatId;
        silent=true;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject=("\E2\9A\A1 " . $RouterName . " | " . $RemoteCmd);
        message=$Output
      });
    } else={
      $SendTelegram2 ({
        chatid=$ChatId;
        silent=false;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject="\E2\9A\A1 TxMTC | Error";
        message=("\E2\9D\8C Failed on *" . $RouterName . "*\n\n" . ($Result->"error"))
      });
    }
  } else={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Error";
      message="Multi-router module not available."
    });
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /hotspot
# ============================================================================

:global HandleHotspot do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ParseCommandParts;
  :global GetHotspotActiveUsers;
  :global FormatHotspotUsers;
  :global DisconnectHotspotUser;
  :global GetHotspotUserInfo;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Load hotspot module if needed
  :global HotspotMonitorLoaded;
  :if ($HotspotMonitorLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/hotspot-monitor";
    } do={}
  }

  :local CmdParts [$ParseCommandParts $Command];
  :local Action ($CmdParts->1);
  :local ResponseMsg "";

  # /hotspot or /hotspot active
  :if ([:len $Action] = 0 || $Action = "active") do={
    :if ([:typeof $GetHotspotActiveUsers] = "array") do={
      :local Users [$GetHotspotActiveUsers];
      :if ([:typeof $FormatHotspotUsers] = "array") do={
        :set ResponseMsg [$FormatHotspotUsers $Users];
      } else={
        :set ResponseMsg ("Active users: " . [:len $Users]);
      }
    } else={
      :set ResponseMsg "Hotspot functions not available.";
    }
  }

  # /hotspot kick <user>
  :if ($Action = "kick" || $Action = "disconnect") do={
    :local Username ($CmdParts->2);
    :if ([:len $Username] > 0 && [:typeof $DisconnectHotspotUser] = "array") do={
      :local Result [$DisconnectHotspotUser $Username];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 User `" . $Username . "` disconnected.");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed to disconnect user: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Usage: `/hotspot kick <username>`";
    }
  }

  # /hotspot info <user>
  :if ($Action = "info") do={
    :local Username ($CmdParts->2);
    :if ([:len $Username] > 0 && [:typeof $GetHotspotUserInfo] = "array") do={
      :local Info [$GetHotspotUserInfo $Username];
      :set ResponseMsg ("*User:* `" . $Username . "`\n\nMAC: `" . ($Info->"mac") . "`\nIP: `" . ($Info->"ip") . "`\nUptime: `" . ($Info->"uptime") . "`");
    } else={
      :set ResponseMsg "Usage: `/hotspot info <username>`";
    }
  }

  :local HotspotCmds ({"/hotspot"; "/hotspot active"; "/menu"});
  :local HotspotButtons [$CreateCommandButtons $HotspotCmds];
  [$SendBotReplyWithButtons $ChatId $ResponseMsg $HotspotButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /bridge
# ============================================================================

:global HandleBridge do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ParseCommandParts;
  :global ListBridges;
  :global ListBridgePorts;
  :global ListVlans;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Load bridge-vlan module if needed
  :global BridgeVlanLoaded;
  :if ($BridgeVlanLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/bridge-vlan";
    } do={}
  }

  :local CmdParts [$ParseCommandParts $Command];
  :local Action ($CmdParts->1);
  :local ResponseMsg "";

  # /bridge or /bridge list
  :if ([:len $Action] = 0 || $Action = "list") do={
    :if ([:typeof $ListBridges] = "array") do={
      :local Bridges [$ListBridges];
      :set ResponseMsg "*Bridges:*\n\n";
      :foreach Bridge in=$Bridges do={
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 `" . ($Bridge->"name") . "` - " . ($Bridge->"port-count") . " ports\n");
      }
    } else={
      :set ResponseMsg "ListBridges not available.";
    }
  }

  # /bridge ports <name>
  :if ($Action = "ports") do={
    :local BridgeName ($CmdParts->2);
    :if ([:len $BridgeName] > 0 && [:typeof $ListBridgePorts] = "array") do={
      :local Ports [$ListBridgePorts $BridgeName];
      :set ResponseMsg ("*Ports in " . $BridgeName . ":*\n\n");
      :foreach Port in=$Ports do={
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 `" . ($Port->"interface") . "` - PVID " . ($Port->"pvid") . "\n");
      }
    } else={
      :set ResponseMsg "Usage: `/bridge ports <bridge-name>`";
    }
  }

  # /bridge vlans
  :if ($Action = "vlans") do={
    :if ([:typeof $ListVlans] = "array") do={
      :local Vlans [$ListVlans];
      :set ResponseMsg "*VLANs:*\n\n";
      :foreach Vlan in=$Vlans do={
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 VLAN " . ($Vlan->"vlan-id") . " on `" . ($Vlan->"bridge") . "`\n");
      }
    } else={
      :set ResponseMsg "ListVlans not available.";
    }
  }

  :local BridgeCmds ({"/bridge"; "/bridge vlans"; "/menu"});
  :local BridgeButtons [$CreateCommandButtons $BridgeCmds];
  [$SendBotReplyWithButtons $ChatId $ResponseMsg $BridgeButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /monitor-interfaces
# ============================================================================

:global HandleMonitorInterfaces do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ParseCommandParts;
  :global GetMonitoredInterfaces;
  :global AddMonitoredInterface;
  :global RemoveMonitoredInterface;
  :global ListAvailableInterfaces;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :local CmdParts [$ParseCommandParts $Command];
  :local Action ($CmdParts->1);
  :local ResponseMsg "";

  # /monitor-interfaces or /monitor-interfaces list
  :if ([:len $Action] = 0 || $Action = "list") do={
    :if ([:typeof $GetMonitoredInterfaces] = "array") do={
      :local Interfaces [$GetMonitoredInterfaces];
      :set ResponseMsg "*Monitored Interfaces:*\n\n";
      :foreach Iface in=$Interfaces do={
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 `" . $Iface . "`\n");
      }
      :if ([:len $Interfaces] = 0) do={
        :set ResponseMsg "No interfaces being monitored.\n\nUse `/monitor-interfaces add <name>` to add one.";
      }
    } else={
      :set ResponseMsg "Interface monitoring not available.";
    }
  }

  # /monitor-interfaces add <name>
  :if ($Action = "add") do={
    :local IfaceName ($CmdParts->2);
    :if ([:len $IfaceName] > 0 && [:typeof $AddMonitoredInterface] = "array") do={
      :local Result [$AddMonitoredInterface $IfaceName];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 Now monitoring `" . $IfaceName . "`");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Usage: `/monitor-interfaces add <interface-name>`";
    }
  }

  # /monitor-interfaces remove <name>
  :if ($Action = "remove") do={
    :local IfaceName ($CmdParts->2);
    :if ([:len $IfaceName] > 0 && [:typeof $RemoveMonitoredInterface] = "array") do={
      :local Result [$RemoveMonitoredInterface $IfaceName];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 Stopped monitoring `" . $IfaceName . "`");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Usage: `/monitor-interfaces remove <interface-name>`";
    }
  }

  # /monitor-interfaces available
  :if ($Action = "available") do={
    :if ([:typeof $ListAvailableInterfaces] = "array") do={
      :local Interfaces [$ListAvailableInterfaces];
      :set ResponseMsg "*Available Interfaces:*\n\n";
      :foreach Iface in=$Interfaces do={
        :set ResponseMsg ($ResponseMsg . "\E2\80\A2 `" . ($Iface->"name") . "` - " . ($Iface->"type") . "\n");
      }
    } else={
      :set ResponseMsg "ListAvailableInterfaces not available.";
    }
  }

  :if ([:len $ResponseMsg] > 0) do={
    :local MonCmds ({"/monitor-interfaces"; "/monitor-interfaces available"; "/menu"});
    :local MonButtons [$CreateCommandButtons $MonCmds];
    [$SendBotReplyWithButtons $ChatId $ResponseMsg $MonButtons $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# REGISTER HANDLERS
# ============================================================================

:global RegisterCommandHandler;
:if ([:typeof $RegisterCommandHandler] = "array") do={
  [$RegisterCommandHandler "^/routers" $HandleRouters 30];
  [$RegisterCommandHandler "^@" $HandleAtRouter 15];
  [$RegisterCommandHandler "^/hotspot" $HandleHotspot 30];
  [$RegisterCommandHandler "^/bridge" $HandleBridge 30];
  [$RegisterCommandHandler "^/monitor-interfaces" $HandleMonitorInterfaces 30];
}

# Mark as loaded
:global NetworkCommandsLoaded
:set NetworkCommandsLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
