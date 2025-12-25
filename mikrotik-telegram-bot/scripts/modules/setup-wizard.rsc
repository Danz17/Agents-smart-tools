#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Setup Wizard Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Interactive setup wizard for configuring the Telegram bot
# Dependencies: shared-functions, telegram-api

# ============================================================================
# LOADING GUARD
# ============================================================================

:global SetupWizardLoaded;
:if ($SetupWizardLoaded = true) do={
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
    :log error "[setup-wizard] - Failed to load shared-functions";
    :return;
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/telegram-api";
  } do={
    :log warning "[setup-wizard] - Telegram API not available";
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global SendTelegramWithKeyboard;
:global CreateInlineKeyboard;
:global EditTelegramMessage;
:global TelegramChatId;
:global TelegramThreadId;
:global TelegramTokenId;
:global SaveBotState;
:global LoadBotState;

# ============================================================================
# CONFIGURATION STATE
# ============================================================================

:global SetupWizardState;
:if ([:typeof $SetupWizardState] != "array") do={
  :set SetupWizardState ({});
}

# ============================================================================
# GET CURRENT CONFIGURATION STATUS
# ============================================================================

:global GetConfigStatus do={
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramChatIdsTrusted;
  :global EnableAutoMonitoring;
  :global EnableAutoBackup;
  :global EnableInteractiveMenus;
  :global ClaudeRelayEnabled;
  :global Identity;

  :local Status ({
    "token_configured"=false;
    "chat_configured"=false;
    "trusted_configured"=false;
    "monitoring_enabled"=false;
    "backup_enabled"=false;
    "menus_enabled"=false;
    "claude_enabled"=false;
    "identity"=$Identity
  });

  :if ([:len $TelegramTokenId] > 10 && $TelegramTokenId != "YOUR_BOT_TOKEN_HERE") do={
    :set ($Status->"token_configured") true;
  }

  :if ([:len $TelegramChatId] > 4 && $TelegramChatId != "YOUR_CHAT_ID_HERE") do={
    :set ($Status->"chat_configured") true;
  }

  :if ([:len $TelegramChatIdsTrusted] > 0) do={
    :set ($Status->"trusted_configured") true;
  }

  :if ($EnableAutoMonitoring = true) do={
    :set ($Status->"monitoring_enabled") true;
  }

  :if ($EnableAutoBackup = true) do={
    :set ($Status->"backup_enabled") true;
  }

  :if ($EnableInteractiveMenus = true) do={
    :set ($Status->"menus_enabled") true;
  }

  :if ($ClaudeRelayEnabled = true) do={
    :set ($Status->"claude_enabled") true;
  }

  :return $Status;
}

# ============================================================================
# FORMAT SETUP STATUS
# ============================================================================

:global FormatSetupStatus do={
  :local Status $1;

  :local Msg "*TxMTC Setup Status*\n\n";

  # Essential configuration
  :set Msg ($Msg . "*Essential:*\n");
  :if (($Status->"token_configured") = true) do={
    :set Msg ($Msg . "  Bot Token configured\n");
  } else={
    :set Msg ($Msg . "  Bot Token not configured\n");
  }

  :if (($Status->"chat_configured") = true) do={
    :set Msg ($Msg . "  Chat ID configured\n");
  } else={
    :set Msg ($Msg . "  Chat ID not configured\n");
  }

  :if (($Status->"trusted_configured") = true) do={
    :set Msg ($Msg . "  Trusted users configured\n");
  } else={
    :set Msg ($Msg . "  No trusted users\n");
  }

  # Features
  :set Msg ($Msg . "\n*Features:*\n");
  :if (($Status->"monitoring_enabled") = true) do={
    :set Msg ($Msg . "  Monitoring: Enabled\n");
  } else={
    :set Msg ($Msg . "  Monitoring: Disabled\n");
  }

  :if (($Status->"backup_enabled") = true) do={
    :set Msg ($Msg . "  Auto-backup: Enabled\n");
  } else={
    :set Msg ($Msg . "  Auto-backup: Disabled\n");
  }

  :if (($Status->"menus_enabled") = true) do={
    :set Msg ($Msg . "  Interactive Menus: Enabled\n");
  } else={
    :set Msg ($Msg . "  Interactive Menus: Disabled\n");
  }

  :if (($Status->"claude_enabled") = true) do={
    :set Msg ($Msg . "  Claude AI: Enabled\n");
  } else={
    :set Msg ($Msg . "  Claude AI: Disabled\n");
  }

  :set Msg ($Msg . "\n*Device:* " . ($Status->"identity"));

  :return $Msg;
}

# ============================================================================
# VALIDATE BOT TOKEN
# ============================================================================

:global ValidateBotToken do={
  :local Token [:tostr $1];

  :if ([:len $Token] < 40) do={
    :return ({valid=false; error="Token too short"});
  }

  :if (!($Token ~ "^[0-9]+:[A-Za-z0-9_-]+\$")) do={
    :return ({valid=false; error="Invalid token format"});
  }

  # Test token by calling getMe
  :onerror Err {
    :local APIUrl ("https://api.telegram.org/bot" . $Token . "/getMe");
    :local Result [/tool/fetch check-certificate=yes-without-crl output=user http-method=get $APIUrl as-value];
    :local Data ($Result->"data");

    :if ($Data ~ "\"ok\":true") do={
      # Extract bot username
      :local UsernamePos [:find $Data "\"username\":\""];
      :local BotUsername "";
      :if ([:typeof $UsernamePos] = "num") do={
        :local Start ($UsernamePos + 12);
        :local End [:find $Data "\"" $Start];
        :set BotUsername [:pick $Data $Start $End];
      }
      :return ({valid=true; username=$BotUsername; error=""});
    } else={
      :return ({valid=false; error="Token rejected by Telegram"});
    }
  } do={
    :return ({valid=false; error=[:tostr $Err]});
  }
}

# ============================================================================
# SET BOT TOKEN
# ============================================================================

:global SetBotToken do={
  :local Token [:tostr $1];

  :global ValidateBotToken;
  :local Validation [$ValidateBotToken $Token];

  :if (($Validation->"valid") != true) do={
    :return ({success=false; error=($Validation->"error")});
  }

  :global TelegramTokenId;
  :set TelegramTokenId $Token;

  :log info ("[setup-wizard] - Bot token configured: @" . ($Validation->"username"));
  :return ({success=true; username=($Validation->"username"); error=""});
}

# ============================================================================
# SET CHAT ID
# ============================================================================

:global SetChatId do={
  :local ChatId [:tostr $1];

  :if ([:len $ChatId] < 5) do={
    :return ({success=false; error="Chat ID too short"});
  }

  :global TelegramChatId;
  :set TelegramChatId $ChatId;

  :log info ("[setup-wizard] - Chat ID configured: " . $ChatId);
  :return ({success=true; error=""});
}

# ============================================================================
# ADD TRUSTED USER
# ============================================================================

:global AddTrustedUser do={
  :local UserId [:tostr $1];

  :if ([:len $UserId] < 3) do={
    :return ({success=false; error="User ID too short"});
  }

  :global TelegramChatIdsTrusted;

  # Check if already trusted
  :if ($TelegramChatIdsTrusted ~ $UserId) do={
    :return ({success=false; error="User already trusted"});
  }

  :if ([:len $TelegramChatIdsTrusted] > 0) do={
    :set TelegramChatIdsTrusted ($TelegramChatIdsTrusted . ";" . $UserId);
  } else={
    :set TelegramChatIdsTrusted $UserId;
  }

  :log info ("[setup-wizard] - Added trusted user: " . $UserId);
  :return ({success=true; error=""});
}

# ============================================================================
# REMOVE TRUSTED USER
# ============================================================================

:global RemoveTrustedUser do={
  :local UserId [:tostr $1];

  :global TelegramChatIdsTrusted;

  :if (!($TelegramChatIdsTrusted ~ $UserId)) do={
    :return ({success=false; error="User not in trusted list"});
  }

  # Simple removal (works for most cases)
  :local NewList "";
  :local Parts ({});
  :local Current "";

  :for I from=0 to=([:len $TelegramChatIdsTrusted] - 1) do={
    :local Char [:pick $TelegramChatIdsTrusted $I ($I + 1)];
    :if ($Char = ";") do={
      :if ([:len $Current] > 0 && $Current != $UserId) do={
        :if ([:len $NewList] > 0) do={
          :set NewList ($NewList . ";" . $Current);
        } else={
          :set NewList $Current;
        }
      }
      :set Current "";
    } else={
      :set Current ($Current . $Char);
    }
  }

  # Handle last item
  :if ([:len $Current] > 0 && $Current != $UserId) do={
    :if ([:len $NewList] > 0) do={
      :set NewList ($NewList . ";" . $Current);
    } else={
      :set NewList $Current;
    }
  }

  :set TelegramChatIdsTrusted $NewList;

  :log info ("[setup-wizard] - Removed trusted user: " . $UserId);
  :return ({success=true; error=""});
}

# ============================================================================
# TOGGLE FEATURE
# ============================================================================

:global ToggleSetupFeature do={
  :local Feature [:tostr $1];
  :local Enable [:tobool $2];

  :if ($Feature = "monitoring") do={
    :global EnableAutoMonitoring;
    :set EnableAutoMonitoring $Enable;
    :log info ("[setup-wizard] - Monitoring: " . [:tostr $Enable]);
    :return ({success=true; error=""});
  }

  :if ($Feature = "backup") do={
    :global EnableAutoBackup;
    :set EnableAutoBackup $Enable;
    :log info ("[setup-wizard] - Auto-backup: " . [:tostr $Enable]);
    :return ({success=true; error=""});
  }

  :if ($Feature = "menus") do={
    :global EnableInteractiveMenus;
    :set EnableInteractiveMenus $Enable;
    :log info ("[setup-wizard] - Interactive menus: " . [:tostr $Enable]);
    :return ({success=true; error=""});
  }

  :if ($Feature = "claude") do={
    :global ClaudeRelayEnabled;
    :set ClaudeRelayEnabled $Enable;
    :log info ("[setup-wizard] - Claude AI: " . [:tostr $Enable]);
    :return ({success=true; error=""});
  }

  :return ({success=false; error="Unknown feature"});
}

# ============================================================================
# SHOW SETUP WIZARD MENU
# ============================================================================

:global ShowSetupWizard do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];

  :global GetConfigStatus;
  :global FormatSetupStatus;
  :global SendTelegramWithKeyboard;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;

  :local Status [$GetConfigStatus];
  :local Msg [$FormatSetupStatus $Status];

  :set Msg ($Msg . "\n\n_Select an option to configure:_");

  :local Buttons ({
    {
      {text="Set Token"; callback_data="setup:token"};
      {text="Set Chat ID"; callback_data="setup:chatid"}
    };
    {
      {text="Trusted Users"; callback_data="setup:trusted"};
      {text="Features"; callback_data="setup:features"}
    };
    {
      {text="Test Connection"; callback_data="setup:test"};
      {text="Export Config"; callback_data="setup:export"}
    };
    {
      {text="BotFather Guide"; callback_data="setup:guide"};
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
# HANDLE SETUP CALLBACKS
# ============================================================================

:global HandleSetupCallback do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local Data [:tostr $3];
  :local ThreadId [:tostr $4];

  :global EditTelegramMessage;
  :global CreateInlineKeyboard;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramChatIdsTrusted;
  :global EnableAutoMonitoring;
  :global EnableAutoBackup;
  :global EnableInteractiveMenus;
  :global ClaudeRelayEnabled;

  # Parse action from callback data (format: setup:<action>:<param>)
  :local Action "";
  :local Param "";
  :local ColonPos [:find $Data ":" 6];  # Find colon after "setup:"
  :if ([:typeof $ColonPos] = "num") do={
    :set Action [:pick $Data 6 $ColonPos];
    :set Param [:pick $Data ($ColonPos + 1) [:len $Data]];
  } else={
    :set Action [:pick $Data 6 [:len $Data]];
  }

  :local ResponseMsg "";
  :local Buttons ({});

  # Set token prompt
  :if ($Action = "token") do={
    :set ResponseMsg ("*Set Bot Token*\n\n" . \
      "1\\. Open @BotFather on Telegram\n" . \
      "2\\. Send `/newbot` to create a bot\n" . \
      "3\\. Copy the token provided\n\n" . \
      "Use command:\n" . \
      "`/setup token <your-bot-token>`\n\n" . \
      "Current: `" . [:pick $TelegramTokenId 0 10] . "...`");
    :set Buttons ({
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Set chat ID prompt
  :if ($Action = "chatid") do={
    :set ResponseMsg ("*Set Chat ID*\n\n" . \
      "Your current chat ID is: `" . $ChatId . "`\n\n" . \
      "To set as admin chat:\n" . \
      "`/setup chatid " . $ChatId . "`\n\n" . \
      "Configured: `" . $TelegramChatId . "`");
    :set Buttons ({
      {{text="Use Current"; callback_data=("setup:setchat:" . $ChatId)}};
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Set chat ID directly
  :if ($Action = "setchat") do={
    :global SetChatId;
    :local Result [$SetChatId $Param];
    :if (($Result->"success") = true) do={
      :set ResponseMsg ("Chat ID configured: `" . $Param . "`");
    } else={
      :set ResponseMsg ("Failed: " . ($Result->"error"));
    }
    :set Buttons ({
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Trusted users
  :if ($Action = "trusted") do={
    :set ResponseMsg ("*Trusted Users*\n\n" . \
      "Current: `" . $TelegramChatIdsTrusted . "`\n\n" . \
      "To add yourself:\n" . \
      "`/setup trust " . $ChatId . "`\n\n" . \
      "To add another user:\n" . \
      "`/setup trust <user-id>`\n\n" . \
      "To remove:\n" . \
      "`/setup untrust <user-id>`");
    :set Buttons ({
      {{text="Add Me"; callback_data=("setup:trust:" . $ChatId)}};
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Add trust
  :if ($Action = "trust") do={
    :global AddTrustedUser;
    :local Result [$AddTrustedUser $Param];
    :if (($Result->"success") = true) do={
      :set ResponseMsg ("Added to trusted users: `" . $Param . "`");
    } else={
      :set ResponseMsg ("Failed: " . ($Result->"error"));
    }
    :set Buttons ({
      {{text="Back"; callback_data="setup:trusted"}}
    });
  }

  # Features menu
  :if ($Action = "features") do={
    :local MonStatus "OFF";
    :local BackupStatus "OFF";
    :local MenuStatus "OFF";
    :local ClaudeStatus "OFF";

    :if ($EnableAutoMonitoring = true) do={ :set MonStatus "ON"; }
    :if ($EnableAutoBackup = true) do={ :set BackupStatus "ON"; }
    :if ($EnableInteractiveMenus = true) do={ :set MenuStatus "ON"; }
    :if ($ClaudeRelayEnabled = true) do={ :set ClaudeStatus "ON"; }

    :set ResponseMsg "*Feature Toggles*\n\nTap to toggle:";
    :set Buttons ({
      {{text=("Monitoring: " . $MonStatus); callback_data="setup:toggle:monitoring"}};
      {{text=("Auto-Backup: " . $BackupStatus); callback_data="setup:toggle:backup"}};
      {{text=("Menus: " . $MenuStatus); callback_data="setup:toggle:menus"}};
      {{text=("Claude AI: " . $ClaudeStatus); callback_data="setup:toggle:claude"}};
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Toggle feature
  :if ($Action = "toggle") do={
    :global ToggleSetupFeature;
    :local CurrentValue false;

    :if ($Param = "monitoring") do={ :set CurrentValue $EnableAutoMonitoring; }
    :if ($Param = "backup") do={ :set CurrentValue $EnableAutoBackup; }
    :if ($Param = "menus") do={ :set CurrentValue $EnableInteractiveMenus; }
    :if ($Param = "claude") do={ :set CurrentValue $ClaudeRelayEnabled; }

    :local NewValue (!$CurrentValue);
    [$ToggleSetupFeature $Param $NewValue];

    # Return to features menu
    :global HandleSetupCallback;
    [$HandleSetupCallback $ChatId $MessageId "setup:features" $ThreadId];
    :return;
  }

  # Test connection
  :if ($Action = "test") do={
    :global SendTelegram2;
    :local TestResult "";
    :onerror Err {
      $SendTelegram2 ({chatid=$ChatId; silent=true; subject="Connection Test"; message="Bot is working correctly\\!"});
      :set TestResult "Connection test successful\\!";
    } do={
      :set TestResult ("Connection failed: " . [:tostr $Err]);
    }
    :set ResponseMsg $TestResult;
    :set Buttons ({
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Export config
  :if ($Action = "export") do={
    :set ResponseMsg ("*Export Configuration*\n\n" . \
      "Copy these commands to restore configuration:\n\n" . \
      "```\n" . \
      ":global TelegramTokenId \"" . $TelegramTokenId . "\";\n" . \
      ":global TelegramChatId \"" . $TelegramChatId . "\";\n" . \
      ":global TelegramChatIdsTrusted \"" . $TelegramChatIdsTrusted . "\";\n" . \
      ":global EnableAutoMonitoring " . [:tostr $EnableAutoMonitoring] . ";\n" . \
      ":global EnableAutoBackup " . [:tostr $EnableAutoBackup] . ";\n" . \
      "```");
    :set Buttons ({
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # BotFather guide
  :if ($Action = "guide") do={
    :set ResponseMsg ("*BotFather Setup Guide*\n\n" . \
      "*Step 1:* Create Your Bot\n" . \
      "1\\. Open @BotFather on Telegram\n" . \
      "2\\. Send `/newbot`\n" . \
      "3\\. Choose a name for your bot\n" . \
      "4\\. Choose a username \\(must end with 'bot'\\)\n" . \
      "5\\. Copy the API token provided\n\n" . \
      "*Step 2:* Configure Commands\n" . \
      "Send `/setcommands` to @BotFather\n" . \
      "Then paste:\n" . \
      "```\n" . \
      "menu - Show main menu\n" . \
      "status - System status\n" . \
      "help - Show help\n" . \
      "hotspot - Hotspot management\n" . \
      "bridge - Bridge/VLAN control\n" . \
      "settings - Bot settings\n" . \
      "```\n\n" . \
      "*Step 3:* Enable Inline Mode \\(optional\\)\n" . \
      "Send `/setinline` for script search");
    :set Buttons ({
      {{text="Back"; callback_data="setup:menu"}}
    });
  }

  # Return to setup menu
  :if ($Action = "menu") do={
    :global ShowSetupWizard;
    [$ShowSetupWizard $ChatId $MessageId $ThreadId];
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

:set SetupWizardLoaded true;
:log info "Setup wizard module loaded"
