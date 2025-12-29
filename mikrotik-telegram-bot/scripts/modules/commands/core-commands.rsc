#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Core Commands Module
# Essential bot control commands: ?, !, /help, /menu, /settings, etc.
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, shared-functions, interactive-menu
#
# Commands:
#   - ? : Quick status query
#   - ! : Activate/deactivate bot
#   - /help : Show help message
#   - /menu : Interactive menu
#   - /settings : User settings
#   - /scripts : Script browser
#   - /modules : Module installer
#   - /cleanup : Message cleanup

# Loading guard
:do {
  :global CoreCommandsLoaded
  :if ($CoreCommandsLoaded) do={ :return }
} on-error={}

:local ScriptName "core-commands";

# Import required globals
:global TelegramChatActive;
:global TelegramChatGroups;
:global Identity;
:global CommandRateLimit;
:global ClaudeRelayEnabled;
:global ClaudeRelayNativeEnabled;
:global SendTelegram2;
:global SendBotReplyWithButtons;
:global CreateCommandButtons;
:global CreateInlineKeyboard;
:global SendTelegramWithKeyboard;
:global RegisterCommandHandler;
:global HandleStatusQuery;
:global HandleActivation;
:global HandleHelp;
:global HandleMenu;
:global HandleSettings;
:global HandleScripts;
:global HandleModules;
:global HandleInstall;
:global HandleCleanup;

# ============================================================================
# COMMAND: ? (Status Query)
# ============================================================================

:global HandleStatusQuery do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global TelegramChatActive;
  :global Identity;
  :global SendTelegramWithKeyboard;
  :global CreateCommandButtons;
  :global CreateInlineKeyboard;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local FirstName ($MsgInfo->"firstName");

  :local ActiveStatus "passive";
  :if ($TelegramChatActive = true) do={ :set ActiveStatus "active"; }

  :local ActivateCmd ("! " . $Identity);
  :local ActivationHint "Ready for commands.";
  :if ($TelegramChatActive = false) do={
    :set ActivationHint ("Send `" . $ActivateCmd . "` to activate.");
  }

  :local StatusMsg ("Hey " . $FirstName . "! Online & " . $ActiveStatus . "\n\n" . $ActivationHint . "\n\n/help");
  :local CommonCmds ({"/status"; "/interfaces"; "/dhcp"; "/logs"});
  :local CommonButtons [$CreateCommandButtons $CommonCmds];
  :local KeyboardJson [$CreateInlineKeyboard $CommonButtons];

  [$SendTelegramWithKeyboard $ChatId $StatusMsg $KeyboardJson $ThreadId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: ! (Activation)
# ============================================================================

:global HandleActivation do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global TelegramChatActive;
  :global TelegramChatGroups;
  :global Identity;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");
  :local FromId ($MsgInfo->"fromId");

  :local ActivationPattern ("^! *(" . $Identity . "|@" . $TelegramChatGroups . ")");

  :if ($Command ~ $ActivationPattern) do={
    :set TelegramChatActive true;
    :local ActivateMsg "\E2\9C\85 *Bot Activated!*\n\nYou can now send RouterOS commands.\n\nTry:\n`/interface print`\n`/ip dhcp-server lease print`\n\nOr use `/help` for more options.";
    :local ActivateCmds ({"/help"; "/status"; "/menu"});
    :local ActivateButtons [$CreateCommandButtons $ActivateCmds];
    [$SendBotReplyWithButtons $ChatId $ActivateMsg $ActivateButtons $ThreadId $MessageId];
    :log info ("[core-commands] - Bot activated by " . $FromId);
  } else={
    :set TelegramChatActive false;
    :local DeactivateMsg ("\E2\9D\8C *Bot Deactivated*\n\nSend `! " . $Identity . "` to activate.");
    [$SendBotReplyWithButtons $ChatId $DeactivateMsg ({}) $ThreadId $MessageId];
    :log info ("[core-commands] - Bot deactivated");
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /help
# ============================================================================

:global HandleHelp do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global TelegramChatActive;
  :global Identity;
  :global CommandRateLimit;
  :global ClaudeRelayEnabled;
  :global ClaudeRelayNativeEnabled;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :local ActivateCmd ("! " . $Identity);
  :local StatusSection "\E2\9C\85 *Bot is active*\nReady for commands.\n\n";
  :if ($TelegramChatActive = false) do={
    :set StatusSection ("\E2\9A\A0\EF\B8\8F *Bot is passive*\nSend `" . $ActivateCmd . "` to activate.\n\n");
  }

  :local ExecuteHint "Send any RouterOS command\n";
  :if ($TelegramChatActive != true) do={
    :set ExecuteHint "Activate first, then send RouterOS commands\n";
  }

  :local SmartSection "";
  :if ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true) do={
    :set SmartSection "\F0\9F\A4\96 *Smart Commands:*\nNatural language (eg show interfaces)\n\n";
  }

  :local ClaudeAuthHint "";
  :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true) do={
    :set ClaudeAuthHint "`/authorize-claude` - Authorize Claude API\n";
  }

  :local HelpText ("*\E2\9A\A1 TxMTC v2.5.0*\n\n" . \
    "\F0\9F\93\B1 *Control:*\n" . \
    "`?` - Status | `" . $ActivateCmd . "` - Activate\n\n" . \
    $StatusSection . \
    "\F0\9F\93\8A *Info Commands:*\n" . \
    "`/status` `/interfaces` `/dhcp` `/logs` `/wireless`\n\n" . \
    "\F0\9F\92\BE *Manage:*\n" . \
    "`/backup` `/update`\n\n" . \
    "\E2\9A\99\EF\B8\8F *Execute:*\n" . \
    $ExecuteHint . \
    $SmartSection . \
    "\F0\9F\9B\A1\EF\B8\8F *Security:*\n" . \
    "Rate: " . $CommandRateLimit . "/min | `CONFIRM code`\n\n" . \
    "\F0\9F\93\8E *Interactive:*\n" . \
    "`/menu` - Interactive menu\n" . \
    "`/modules` - Install/manage modules\n" . \
    "`/scripts` - List available scripts\n" . \
    "`/settings` - User preferences\n" . \
    "`/cleanup` - Clean old messages\n" . \
    $ClaudeAuthHint . \
    "\n\E2\94\80\E2\94\80\E2\94\80\n_by Phenix_");

  :local HelpCmds ({"/status"; "/interfaces"; "/dhcp"; "/logs"; "/menu"; "/modules"});
  :local HelpButtons [$CreateCommandButtons $HelpCmds];
  [$SendBotReplyWithButtons $ChatId $HelpText $HelpButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /menu
# ============================================================================

:global HandleMenu do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ShowInteractiveMenu;
  :global SendBotReplyWithButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :if ([:typeof $ShowInteractiveMenu] = "array") do={
    [$ShowInteractiveMenu $ChatId "0" $ThreadId];
  } else={
    :local MenuMsg "\E2\9A\A1 *TxMTC Menu*\n\nInteractive menu not loaded.\n\nUse `/help` for commands.";
    [$SendBotReplyWithButtons $ChatId $MenuMsg ({}) $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /settings
# ============================================================================

:global HandleSettings do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global FormatUserSettings;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :if ([:typeof $FormatUserSettings] = "array") do={
    :local SettingsText [$FormatUserSettings $ChatId];
    :local SettingsCmds ({"/menu"; "/help"; "/cleanup"});
    :local SettingsButtons [$CreateCommandButtons $SettingsCmds];
    [$SendBotReplyWithButtons $ChatId $SettingsText $SettingsButtons $ThreadId $MessageId];
  } else={
    :local ErrorMsg "Settings module not loaded.";
    [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /scripts
# ============================================================================

:global HandleScripts do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ListScriptCategories;
  :global ListScriptsByCategory;
  :global Capitalize;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Parse category from command
  :local Category "";
  :if ([:len $Command] > 9) do={
    :set Category [:pick $Command 9 [:len $Command]];
  }

  :if ([:len $Category] > 0) do={
    # List scripts in category
    :if ([:typeof $ListScriptsByCategory] = "array") do={
      :local Scripts [$ListScriptsByCategory $Category];
      :if ([:len $Scripts] > 0) do={
        :local ScriptList ("*Scripts in " . $Category . ":*\n\n");
        :foreach Script in=$Scripts do={
          :set ScriptList ($ScriptList . "\E2\80\A2 `" . ($Script->"name") . "`\n  " . ($Script->"description") . "\n\n");
        }
        :local ScriptCmds ({"/scripts"; "/install"; "/menu"});
        :local ScriptButtons [$CreateCommandButtons $ScriptCmds];
        [$SendBotReplyWithButtons $ChatId $ScriptList $ScriptButtons $ThreadId $MessageId];
      } else={
        [$SendBotReplyWithButtons $ChatId ("No scripts in category: " . $Category) ({}) $ThreadId $MessageId];
      }
    } else={
      [$SendBotReplyWithButtons $ChatId "Script registry not available." ({}) $ThreadId $MessageId];
    }
  } else={
    # List categories
    :if ([:typeof $ListScriptCategories] = "array") do={
      :local Categories [$ListScriptCategories];
      :local CatList ("*Available Categories:*\n\n");
      :foreach Cat in=$Categories do={
        :local CatName $Cat;
        :if ([:typeof $Capitalize] = "array") do={
          :set CatName [$Capitalize $Cat];
        }
        :set CatList ($CatList . "\E2\80\A2 " . $CatName . "\n");
      }
      :set CatList ($CatList . "\nUse `/scripts <category>` to list scripts.");
      :local CatCmds ({"/menu"; "/modules"; "/help"});
      :local CatButtons [$CreateCommandButtons $CatCmds];
      [$SendBotReplyWithButtons $ChatId $CatList $CatButtons $ThreadId $MessageId];
    } else={
      [$SendBotReplyWithButtons $ChatId "Script registry not available." ({}) $ThreadId $MessageId];
    }
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /modules
# ============================================================================

:global HandleModules do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global SendTelegram2;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :local ModulesMsg "*\F0\9F\93\A6 TxMTC Modules*\n\nAvailable add-on modules:\n\n";
  :set ModulesMsg ($ModulesMsg . "\E2\80\A2 *hotspot-monitor* - Hotspot user tracking\n");
  :set ModulesMsg ($ModulesMsg . "\E2\80\A2 *bridge-vlan* - VLAN management\n");
  :set ModulesMsg ($ModulesMsg . "\E2\80\A2 *multi-router* - Multi-device control\n");
  :set ModulesMsg ($ModulesMsg . "\E2\80\A2 *daily-summary* - Usage reports\n");
  :set ModulesMsg ($ModulesMsg . "\E2\80\A2 *error-monitor* - Error alerts\n\n");
  :set ModulesMsg ($ModulesMsg . "Use `/install <module>` to install.");

  :local ModuleButtons ({
    {{"text"="Hotspot Monitor"; "callback_data"="/install hotspot-monitor"}};
    {{"text"="Bridge VLAN"; "callback_data"="/install bridge-vlan"}};
    {{"text"="Multi-Router"; "callback_data"="/install multi-router"}};
    {{"text"="Back to Menu"; "callback_data"="/menu"}}
  });

  :local KeyboardJson [$CreateInlineKeyboard $ModuleButtons];
  [$SendTelegramWithKeyboard $ChatId $ModulesMsg $KeyboardJson $ThreadId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /install
# ============================================================================

:global HandleInstall do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global InstallModule;
  :global SendTelegram2;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Parse module name
  :local ModuleName "";
  :if ([:len $Command] > 9) do={
    :set ModuleName [:pick $Command 9 [:len $Command]];
  }

  :if ([:len $ModuleName] = 0) do={
    # Show modules list
    :local ModulesMsg "*Available Modules:*\n\n";
    :set ModulesMsg ($ModulesMsg . "`/install hotspot-monitor`\n");
    :set ModulesMsg ($ModulesMsg . "`/install bridge-vlan`\n");
    :set ModulesMsg ($ModulesMsg . "`/install multi-router`\n");
    :set ModulesMsg ($ModulesMsg . "`/install daily-summary`\n");
    :local InstCmds ({"/modules"; "/menu"; "/help"});
    :local InstButtons [$CreateCommandButtons $InstCmds];
    [$SendBotReplyWithButtons $ChatId $ModulesMsg $InstButtons $ThreadId $MessageId];
    :return ({ "handled"=true });
  }

  :if ([:typeof $InstallModule] = "array") do={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=true;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Installing";
      message=("Installing module: `" . $ModuleName . "`...")
    });

    :local Result [$InstallModule $ModuleName];
    :if (($Result->"success") = true) do={
      :local SuccessMsg ("\E2\9C\85 Successfully installed `" . $ModuleName . "`\n\n" . ($Result->"message"));
      :local SuccCmds ({"/modules"; "/menu"; "/help"});
      :local SuccButtons [$CreateCommandButtons $SuccCmds];
      [$SendBotReplyWithButtons $ChatId $SuccessMsg $SuccButtons $ThreadId $MessageId];
    } else={
      :local FailMsg ("\E2\9D\8C Failed to install `" . $ModuleName . "`\n\n" . ($Result->"error"));
      [$SendBotReplyWithButtons $ChatId $FailMsg ({}) $ThreadId $MessageId];
    }
  } else={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Error";
      message="Interactive installer not available. Use /scripts to view available modules."
    });
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /cleanup
# ============================================================================

:global HandleCleanup do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global CleanupOldMessages;
  :global MessageRetentionPeriod;
  :global KeepCriticalMessages;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :if ([:typeof $CleanupOldMessages] = "array") do={
    :local Result [$CleanupOldMessages $MessageRetentionPeriod $KeepCriticalMessages];
    :local CleanupMsg ("\F0\9F\97\91\EF\B8\8F *Cleanup Complete*\n\nDeleted " . ($Result->"deleted") . " old messages.");
    :local CleanupCmds ({"/menu"; "/settings"; "/help"});
    :local CleanupButtons [$CreateCommandButtons $CleanupCmds];
    [$SendBotReplyWithButtons $ChatId $CleanupMsg $CleanupButtons $ThreadId $MessageId];
  } else={
    [$SendBotReplyWithButtons $ChatId "Cleanup function not available." ({}) $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# REGISTER HANDLERS
# ============================================================================

:global RegisterCommandHandler;
:global HandleStatusQuery;
:global HandleActivation;
:global HandleHelp;
:global HandleMenu;
:global HandleSettings;
:global HandleScripts;
:global HandleModules;
:global HandleInstall;
:global HandleCleanup;
:if ([:typeof $RegisterCommandHandler] = "array") do={
  [$RegisterCommandHandler "QMARK" $HandleStatusQuery 10];
  [$RegisterCommandHandler "^!" $HandleActivation 10];
  [$RegisterCommandHandler "^/help" $HandleHelp 10];
  [$RegisterCommandHandler "^/menu" $HandleMenu 20];
  [$RegisterCommandHandler "^/settings" $HandleSettings 20];
  [$RegisterCommandHandler "^/scripts" $HandleScripts 20];
  [$RegisterCommandHandler "^/modules" $HandleModules 20];
  [$RegisterCommandHandler "^/install " $HandleInstall 20];
  [$RegisterCommandHandler "^/cleanup" $HandleCleanup 20];
}

# Mark as loaded
:global CoreCommandsLoaded
:set CoreCommandsLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
