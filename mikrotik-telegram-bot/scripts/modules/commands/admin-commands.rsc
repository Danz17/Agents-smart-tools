#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Admin Commands Module
# Administrative and setup commands: /setup, /update, /authorize-claude
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, auto-updater, setup-wizard, claude-relay-native
#
# Commands:
#   - /setup : Initial configuration wizard
#   - /update : Check and install updates
#   - /authorize-claude : Claude API authorization
#   - /monitoring-settings : Monitoring configuration

# Loading guard
:do {
  :global AdminCommandsLoaded
  :if ($AdminCommandsLoaded) do={ :return }
} on-error={}

:local ScriptName "admin-commands";

# Import required globals
:global TelegramChatId;
:global SendTelegram2;
:global SendBotReplyWithButtons;
:global CreateCommandButtons;
:global CreateInlineKeyboard;
:global SendTelegramWithKeyboard;
:global RegisterCommandHandler;
:global ClaudeRelayNativeEnabled;
:global ClaudeRelayURL;

# ============================================================================
# COMMAND: /monitoring-settings
# ============================================================================

:global HandleMonitoringSettings do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ShowMonitoringSettings;
  :global SendBotReplyWithButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :if ([:typeof $ShowMonitoringSettings] = "array") do={
    [$ShowMonitoringSettings $ChatId "0" $ThreadId];
  } else={
    :local ErrorMsg "Monitoring settings menu not available.";
    [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /authorize-claude
# ============================================================================

:global HandleAuthorizeClaude do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global ClaudeRelayNativeEnabled;
  :global ClaudeRelayURL;
  :global AuthorizeDevice;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :if ([:typeof $ClaudeRelayNativeEnabled] != "bool" || $ClaudeRelayNativeEnabled != true) do={
    :local ErrorMsg "\F0\9F\94\90 *Claude Authorization*\n\nNative Claude relay is not enabled.\n\nEnable it first:\n`:global ClaudeRelayNativeEnabled true`";
    [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
    :return ({ "handled"=true });
  }

  :if ([:len $ClaudeRelayURL] = 0) do={
    :local ErrorMsg "\F0\9F\94\90 *Claude Authorization*\n\nClaude relay service URL not configured.\n\nSet it first:\n`:global ClaudeRelayURL \"http://your-server:5000\"`";
    [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
    :return ({ "handled"=true });
  }

  # Load claude-relay-native if needed
  :global ClaudeRelayNativeLoaded;
  :if ($ClaudeRelayNativeLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/claude-relay-native";
    } do={}
  }

  :if ([:typeof $AuthorizeDevice] = "array") do={
    :local AuthMsg "\F0\9F\94\90 *Starting Device Authorization*\n\nRequesting authorization code...";
    [$SendBotReplyWithButtons $ChatId $AuthMsg ({}) $ThreadId $MessageId];

    :local AuthResult [$AuthorizeDevice];

    :if (($AuthResult->"success") = true) do={
      :local SuccessMsg "\E2\9C\85 *Device Authorized Successfully!*\n\nYour Claude API key has been stored on this router.\n\nYou can now use smart commands!";
      :local SuccessCmds ({"/help"; "/status"});
      :local SuccessButtons [$CreateCommandButtons $SuccessCmds];
      [$SendBotReplyWithButtons $ChatId $SuccessMsg $SuccessButtons $ThreadId $MessageId];
    } else={
      :local ErrorMsg ("\E2\9D\8C *Authorization Failed*\n\n" . ($AuthResult->"error") . "\n\nPlease try again or check the service URL.");
      [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
    }
  } else={
    :local ErrorMsg "\F0\9F\94\90 *Claude Authorization*\n\nAuthorization function not available.\n\nMake sure `claude-relay-native` module is loaded.";
    [$SendBotReplyWithButtons $ChatId $ErrorMsg ({}) $ThreadId $MessageId];
  }

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /update
# ============================================================================

:global HandleUpdate do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Load auto-updater module
  :global AutoUpdaterLoaded;
  :if ($AutoUpdaterLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/auto-updater";
    } do={
      :log warning "[admin-commands] - Could not load auto-updater module";
    }
  }

  :global CheckForUpdates;
  :global FormatUpdateNotification;
  :global InstallUpdate;
  :global InstallAllUpdates;
  :global TxMTCVersion;

  # Parse subcommand
  :local SubCmd "";
  :local SubArg "";
  :if ([:len $Command] > 8) do={
    :local Rest [:pick $Command 8 [:len $Command]];
    :local SpacePos [:find $Rest " "];
    :if ([:typeof $SpacePos] = "num") do={
      :set SubCmd [:pick $Rest 0 $SpacePos];
      :set SubArg [:pick $Rest ($SpacePos + 1) [:len $Rest]];
    } else={
      :set SubCmd $Rest;
    }
  }

  :local ResponseMsg "";

  # /update or /update check
  :if ($SubCmd = "" || $SubCmd = "check") do={
    :if ([:typeof $CheckForUpdates] = "array") do={
      :local Updates [$CheckForUpdates];
      :if ([:typeof $FormatUpdateNotification] = "array") do={
        :set ResponseMsg [$FormatUpdateNotification $Updates];
      } else={
        :set ResponseMsg ("Found " . ($Updates->"count") . " updates available.");
      }
    } else={
      :set ResponseMsg "Update checker not available.";
    }
  }

  # /update install <module>
  :if ($SubCmd = "install" && [:len $SubArg] > 0) do={
    :if ([:typeof $InstallUpdate] = "array") do={
      :local Result [$InstallUpdate $SubArg];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 Successfully updated `" . $SubArg . "`");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed to update: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Update installer not available.";
    }
  }

  # /update all
  :if ($SubCmd = "all") do={
    :if ([:typeof $InstallAllUpdates] = "array") do={
      :local Result [$InstallAllUpdates];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 Updated " . ($Result->"updated") . " script(s)");
      } else={
        :set ResponseMsg ("\E2\9A\A0\EF\B8\8F Updated " . ($Result->"updated") . ", failed " . ($Result->"failed"));
      }
    } else={
      :set ResponseMsg "Update installer not available.";
    }
  }

  # /update version
  :if ($SubCmd = "version") do={
    :if ([:typeof $TxMTCVersion] = "str") do={
      :set ResponseMsg ("\F0\9F\A4\96 *TxMTC Version*: `" . $TxMTCVersion . "`");
    } else={
      :set ResponseMsg "Version information not available.";
    }
  }

  :local UpdateCmds ({"/update check"; "/update all"; "/menu"});
  :local UpdateButtons [$CreateCommandButtons $UpdateCmds];
  [$SendBotReplyWithButtons $ChatId $ResponseMsg $UpdateButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# COMMAND: /setup
# ============================================================================

:global HandleSetup do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global SendTelegram2;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  # Load setup wizard module
  :global SetupWizardLoaded;
  :if ($SetupWizardLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/setup-wizard";
    } do={
      :log warning "[admin-commands] - Could not load setup-wizard module";
    }
  }

  :global ShowSetupMenu;
  :global SetBotToken;
  :global SetChatId;
  :global AddTrustedUser;
  :global RemoveTrustedUser;

  # Parse subcommand
  :local SubCmd "";
  :local SubArg "";
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

  :if ([:len $CmdParts] > 1) do={ :set SubCmd ($CmdParts->1); }
  :if ([:len $CmdParts] > 2) do={ :set SubArg ($CmdParts->2); }

  :local ResponseMsg "";

  # /setup or /setup menu
  :if ($SubCmd = "" || $SubCmd = "menu") do={
    :if ([:typeof $ShowSetupMenu] = "array") do={
      [$ShowSetupMenu $ChatId "0" $ThreadId];
      :return ({ "handled"=true });
    } else={
      :set ResponseMsg ("*\E2\9A\99\EF\B8\8F Setup Wizard*\n\n" . \
        "Available commands:\n" . \
        "`/setup token <token>` - Set bot token\n" . \
        "`/setup chatid <id>` - Set primary chat ID\n" . \
        "`/setup trust <id>` - Add trusted user\n" . \
        "`/setup untrust <id>` - Remove trusted user\n");
    }
  }

  # /setup token <token>
  :if ($SubCmd = "token" && [:len $SubArg] > 0) do={
    :if ([:typeof $SetBotToken] = "array") do={
      :local Result [$SetBotToken $SubArg];
      :if (($Result->"success") = true) do={
        :set ResponseMsg "\E2\9C\85 Bot token updated successfully.\n\nRestart the bot for changes to take effect.";
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed to set token: " . ($Result->"error"));
      }
    } else={
      :global TelegramTokenId;
      :set TelegramTokenId $SubArg;
      :set ResponseMsg "\E2\9C\85 Bot token set. Run `/system script run bot-config` to apply.";
    }
  }

  # /setup chatid <id>
  :if ($SubCmd = "chatid" && [:len $SubArg] > 0) do={
    :if ([:typeof $SetChatId] = "array") do={
      :local Result [$SetChatId $SubArg];
      :if (($Result->"success") = true) do={
        :set ResponseMsg "\E2\9C\85 Chat ID updated successfully.";
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed to set chat ID: " . ($Result->"error"));
      }
    } else={
      :global TelegramChatId;
      :set TelegramChatId $SubArg;
      :set ResponseMsg "\E2\9C\85 Chat ID set. Run `/system script run bot-config` to apply.";
    }
  }

  # /setup trust <id>
  :if ($SubCmd = "trust" && [:len $SubArg] > 0) do={
    :if ([:typeof $AddTrustedUser] = "array") do={
      :local Result [$AddTrustedUser $SubArg];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 User `" . $SubArg . "` added to trusted list.");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Trust management not available. Edit `TelegramChatIdsTrusted` manually.";
    }
  }

  # /setup untrust <id>
  :if ($SubCmd = "untrust" && [:len $SubArg] > 0) do={
    :if ([:typeof $RemoveTrustedUser] = "array") do={
      :local Result [$RemoveTrustedUser $SubArg];
      :if (($Result->"success") = true) do={
        :set ResponseMsg ("\E2\9C\85 User `" . $SubArg . "` removed from trusted list.");
      } else={
        :set ResponseMsg ("\E2\9D\8C Failed: " . ($Result->"error"));
      }
    } else={
      :set ResponseMsg "Trust management not available. Edit `TelegramChatIdsTrusted` manually.";
    }
  }

  :local SetupCmds ({"/setup"; "/help"; "/menu"});
  :local SetupButtons [$CreateCommandButtons $SetupCmds];
  [$SendBotReplyWithButtons $ChatId $ResponseMsg $SetupButtons $ThreadId $MessageId];

  :return ({ "handled"=true });
}

# ============================================================================
# REGISTER HANDLERS
# ============================================================================

:global RegisterCommandHandler;
:if ([:typeof $RegisterCommandHandler] = "array") do={
  [$RegisterCommandHandler "^/monitoring-settings" $HandleMonitoringSettings 30];
  [$RegisterCommandHandler "^/authorize-claude" $HandleAuthorizeClaude 30];
  [$RegisterCommandHandler "^/update" $HandleUpdate 30];
  [$RegisterCommandHandler "^/setup" $HandleSetup 30];
}

# Mark as loaded
:global AdminCommandsLoaded
:set AdminCommandsLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
