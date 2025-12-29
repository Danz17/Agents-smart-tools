#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# Bot Core - Orchestrator (Modular Version)
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# Version: 2.5.0 (Modular Architecture)
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
# requires device-mode, fetch
#
# Dependencies: bot-config, modules/telegram-handler, modules/message-router,
#               modules/command-dispatcher, modules/execution-engine

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded. Run bot-config first."); }; } delay=500ms max=50;
  :local ScriptName [: jobname];

  # ============================================================================
  # LOAD CORE MODULES
  # ============================================================================

  # Import shared functions module (required by all)
  :global SharedFunctionsLoaded;
  :if ($SharedFunctionsLoaded != true) do={
    :onerror ModErr { /system script run "modules/shared-functions"; } do={
      :log warning ($ScriptName . " - Could not load shared-functions module");
    }
  }

  # Import telegram-api module
  :global TelegramAPILoaded;
  :if ($TelegramAPILoaded != true) do={
    :onerror ModErr { /system script run "modules/telegram-api"; } do={
      :log warning ($ScriptName . " - Could not load telegram-api module");
    }
  }

  # Import security module
  :global SecurityModuleLoaded;
  :if ($SecurityModuleLoaded != true) do={
    :onerror ModErr { /system script run "modules/security"; } do={
      :log warning ($ScriptName . " - Could not load security module");
    }
  }

  # Import telegram-handler module
  :global TelegramHandlerLoaded;
  :if ($TelegramHandlerLoaded != true) do={
    :onerror ModErr { /system script run "modules/telegram-handler"; } do={
      :log warning ($ScriptName . " - Could not load telegram-handler module");
    }
  }

  # Import message-router module
  :global MessageRouterLoaded;
  :if ($MessageRouterLoaded != true) do={
    :onerror ModErr { /system script run "modules/message-router"; } do={
      :log warning ($ScriptName . " - Could not load message-router module");
    }
  }

  # Import command-dispatcher module
  :global CommandDispatcherLoaded;
  :if ($CommandDispatcherLoaded != true) do={
    :onerror ModErr { /system script run "modules/command-dispatcher"; } do={
      :log warning ($ScriptName . " - Could not load command-dispatcher module");
    }
  }

  # Import execution-engine module
  :global ExecutionEngineLoaded;
  :if ($ExecutionEngineLoaded != true) do={
    :onerror ModErr { /system script run "modules/execution-engine"; } do={
      :log warning ($ScriptName . " - Could not load execution-engine module");
    }
  }

  # Import interactive menu module
  :global InteractiveMenuLoaded;
  :if ($InteractiveMenuLoaded != true) do={
    :onerror ModErr { /system script run "modules/interactive-menu"; } do={
      :log warning ($ScriptName . " - Could not load interactive-menu module");
    }
  }

  # Import smart-processor module (if AI enabled)
  :global ClaudeRelayEnabled;
  :global ClaudeRelayNativeEnabled;
  :if (([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true) || \
       ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true)) do={
    :global SmartProcessorLoaded;
    :if ($SmartProcessorLoaded != true) do={
      :onerror ModErr { /system script run "modules/smart-processor"; } do={
        :log warning ($ScriptName . " - Could not load smart-processor module");
      }
    }
  }

  # ============================================================================
  # IMPORT ORCHESTRATOR FUNCTIONS
  # ============================================================================

  # Configuration
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramChatOffset;
  :global TelegramChatActive;
  :global TelegramRandomDelay;
  :global Identity;

  # Core module functions
  :global InitializeOffsets;
  :global FetchBotUpdates;
  :global ProcessUpdateQueue;
  :global HandleCallbackQueryEvent;
  :global HandleInlineQueryEvent;
  :global UpdateMessageOffset;
  :global GetUpdateType;
  :global RouteMessage;
  :global DispatchCommand;
  :global HandleUntrustedUser;
  :global ProcessSmartPipeline;
  :global LoadRelayModules;

  # Telegram functions
  :global SendTelegram2;
  :global SendBotReplyWithButtons;
  :global CreateCommandButtons;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;

  # Adaptive polling
  :global AdjustPollingInterval;
  :global UpdateLastMessageTime;

  # ============================================================================
  # HELPER: SEND BOT REPLY WITH BUTTONS
  # ============================================================================

  :global SendBotReplyWithButtons do={
    :local ChatId [:tostr $1];
    :local MessageText [:tostr $2];
    :local Buttons $3;
    :local ThreadId [:tostr $4];
    :local ReplyTo [:tostr $5];

    :global SendTelegramWithKeyboard;
    :global CreateInlineKeyboard;
    :global SendTelegram2;

    :if ([:typeof $SendTelegramWithKeyboard] != "array") do={
      $SendTelegram2 ({ chatid=$ChatId; subject=""; message=$MessageText; replyto=$ReplyTo; threadid=$ThreadId; silent=true });
      :return "";
    }

    :local KeyboardJson "";
    :if ([:typeof $Buttons] = "array" && [:len $Buttons] > 0) do={
      :if ([:typeof $CreateInlineKeyboard] = "array") do={
        :set KeyboardJson [$CreateInlineKeyboard $Buttons];
      }
    }

    :local Result [$SendTelegramWithKeyboard $ChatId $MessageText $KeyboardJson $ThreadId];
    :return $Result;
  }

  # ============================================================================
  # VALIDATE CONFIGURATION
  # ============================================================================

  :if ([:len $TelegramTokenId] = 0 || $TelegramTokenId = "YOUR_BOT_TOKEN_HERE") do={
    :log error ($ScriptName . " - TelegramTokenId not configured!");
    :set ExitOK true;
    :error false;
  }

  # ============================================================================
  # INITIALIZE STATE
  # ============================================================================

  :if ([:typeof $InitializeOffsets] = "array") do={
    [$InitializeOffsets];
  } else={
    # Fallback initialization
    :if ([:typeof $TelegramChatOffset] != "array") do={
      :set TelegramChatOffset { 0; 0; 0 };
    }
  }

  # ============================================================================
  # VERSION CHECK ON STARTUP (once per day)
  # ============================================================================

  :global LastStartupUpdateCheck;
  :global AutoUpdateNotify;
  :if ([:typeof $LastStartupUpdateCheck] != "time") do={
    :set LastStartupUpdateCheck 0s;
  }

  :local CurrentTime [/system clock get time];
  :local TimeSinceCheck ($CurrentTime - $LastStartupUpdateCheck);

  :if ($TimeSinceCheck > 1d || $LastStartupUpdateCheck = 0s) do={
    :set LastStartupUpdateCheck $CurrentTime;
    :onerror UpdateErr {
      :global AutoUpdaterLoaded;
      :if ($AutoUpdaterLoaded != true) do={
        /system script run "modules/auto-updater";
      }
      :global CheckForUpdates;
      :global FormatUpdateNotification;
      :if ([:typeof $CheckForUpdates] = "array" && $AutoUpdateNotify = true) do={
        :local Updates [$CheckForUpdates];
        :if (($Updates->"count") > 0) do={
          :local Msg [$FormatUpdateNotification $Updates];
          $SendTelegram2 ({ chatid=$TelegramChatId; silent=true; subject="\F0\9F\94\84 TxMTC Startup Check"; message=$Msg });
        }
      }
    } do={}
  }

  # ============================================================================
  # ADAPTIVE POLLING
  # ============================================================================

  :if ([:typeof $AdjustPollingInterval] = "array") do={
    [$AdjustPollingInterval];
  }

  # ============================================================================
  # RANDOM DELAY (prevent simultaneous polling)
  # ============================================================================

  :if ([:typeof $TelegramRandomDelay] = "num" && $TelegramRandomDelay > 0) do={
    :local RndDelay [:rndnum from=0 to=$TelegramRandomDelay];
    :delay ($RndDelay . "s");
  }

  # ============================================================================
  # FETCH UPDATES FROM TELEGRAM
  # ============================================================================

  :local FetchResult;
  :if ([:typeof $FetchBotUpdates] = "array") do={
    :set FetchResult [$FetchBotUpdates];
  } else={
    :log warning ($ScriptName . " - FetchBotUpdates not available");
    :set ExitOK true;
    :error false;
  }

  :if (($FetchResult->"success") != true) do={
    :log warning ($ScriptName . " - " . ($FetchResult->"error"));
    :set ExitOK true;
    :error false;
  }

  :local Results ($FetchResult->"results");

  # ============================================================================
  # PROCESS UPDATE QUEUE
  # ============================================================================

  :if ([:typeof $ProcessUpdateQueue] = "array") do={
    :local QueueResult [$ProcessUpdateQueue $Results];
    :if (($QueueResult->"action") = "cleared") do={
      :log info ($ScriptName . " - Queue cleared, skipped " . ($QueueResult->"skipped") . " messages");
      :set ExitOK true;
      :error false;
    }
    :set Results ($QueueResult->"results");
  }

  # ============================================================================
  # MAIN UPDATE PROCESSING LOOP
  # ============================================================================

  :local UpdateID 0;

  :foreach Update in=$Results do={
    :set UpdateID ($Update->"update_id");
    :log debug ($ScriptName . " - Processing update " . $UpdateID);

    # Determine update type
    :local UpdateType "unknown";
    :if ([:typeof $GetUpdateType] = "array") do={
      :set UpdateType [$GetUpdateType $Update];
    } else={
      :if ([:typeof ($Update->"callback_query")] = "array") do={ :set UpdateType "callback"; }
      :if ([:typeof ($Update->"inline_query")] = "array") do={ :set UpdateType "inline"; }
      :if ([:typeof ($Update->"message")] = "array") do={ :set UpdateType "message"; }
    }

    # ─────────────────────────────────────────────────────────────────────────
    # HANDLE CALLBACK QUERIES (inline keyboard buttons)
    # ─────────────────────────────────────────────────────────────────────────

    :if ($UpdateType = "callback") do={
      :if ([:typeof $HandleCallbackQueryEvent] = "array") do={
        :local CallbackResult [$HandleCallbackQueryEvent ($Update->"callback_query")];

        # If callback returned a command to execute, process it
        :if (($CallbackResult->"action") = "execute_command") do={
          :local CmdToExecute ($CallbackResult->"command");
          :log info ($ScriptName . " - Callback command: " . $CmdToExecute);

          # Build mock route result for dispatcher
          :local MockRouteResult ({
            "shouldProcess"=true;
            "shouldExecute"=true;
            "trusted"=true;
            "updateId"=$UpdateID;
            "commandType"="callback_command";
            "command"=$CmdToExecute;
            "targetRouter"="";
            "messageInfo"=({
              "chatId"=($CallbackResult->"chatId");
              "fromId"=($CallbackResult->"chatId");
              "messageId"=($CallbackResult->"messageId");
              "threadId"=($CallbackResult->"threadId");
              "from"=($CallbackResult->"from")
            })
          });

          :if ([:typeof $DispatchCommand] = "array") do={
            [$DispatchCommand $MockRouteResult];
          }
        }
      }
    }

    # ─────────────────────────────────────────────────────────────────────────
    # HANDLE INLINE QUERIES (script search)
    # ─────────────────────────────────────────────────────────────────────────

    :if ($UpdateType = "inline") do={
      :if ([:typeof $HandleInlineQueryEvent] = "array") do={
        [$HandleInlineQueryEvent ($Update->"inline_query")];
      }
    }

    # ─────────────────────────────────────────────────────────────────────────
    # HANDLE MESSAGES
    # ─────────────────────────────────────────────────────────────────────────

    :if ($UpdateType = "message") do={
      # Route message
      :local RouteResult ({});
      :if ([:typeof $RouteMessage] = "array") do={
        :set RouteResult [$RouteMessage $Update];
      }

      # Handle untrusted users
      :if (($RouteResult->"trusted") != true && ($RouteResult->"reason") = "untrusted") do={
        :if ([:typeof $HandleUntrustedUser] = "array") do={
          [$HandleUntrustedUser ($RouteResult->"messageInfo") ($RouteResult->"command")];
        }
      }

      # Process trusted messages
      :if (($RouteResult->"shouldProcess") = true && ($RouteResult->"trusted") = true) do={
        :local Command ($RouteResult->"command");
        :local MsgInfo ($RouteResult->"messageInfo");

        # Process through smart pipeline (handles AI translation and custom aliases)
        :local ProcessedCmd $Command;
        :local ShouldExecute ($RouteResult->"shouldExecute");

        :if ([:typeof $ProcessSmartPipeline] = "array") do={
          :local SmartResult [$ProcessSmartPipeline $Command $MsgInfo];
          :set ProcessedCmd ($SmartResult->"command");
          :if (($SmartResult->"shouldExecute") = false) do={
            :set ShouldExecute false;
          }
        }

        # Update route result with processed command
        :set ($RouteResult->"command") $ProcessedCmd;
        :set ($RouteResult->"shouldExecute") $ShouldExecute;

        # Dispatch to handler
        :if ([:typeof $DispatchCommand] = "array") do={
          :local DispatchResult [$DispatchCommand $RouteResult];
          :log debug ($ScriptName . " - Dispatch result: " . ($DispatchResult->"action"));
        }
      }
    }
  }

  # ============================================================================
  # UPDATE OFFSET
  # ============================================================================

  :if ([:typeof $UpdateMessageOffset] = "array") do={
    [$UpdateMessageOffset $UpdateID];
  } else={
    # Fallback offset update
    :local NewOffset;
    :if ($UpdateID >= $TelegramChatOffset->2) do={
      :set NewOffset ($UpdateID + 1);
    } else={
      :set NewOffset ($TelegramChatOffset->2);
    }
    :set TelegramChatOffset ([:pick $TelegramChatOffset 1 3], $NewOffset);
  }

  # ============================================================================
  # AUTO CLEANUP (periodic)
  # ============================================================================

  :global AutoCleanupEnabled;
  :global CleanupInterval;
  :global LastCleanupTime;
  :global AutoCleanupMessages;

  :if ([:typeof $AutoCleanupEnabled] = "bool" && $AutoCleanupEnabled = true) do={
    :if ([:typeof $LastCleanupTime] != "time") do={
      :set LastCleanupTime [/system clock get time];
    }
    :if ([:typeof $CleanupInterval] != "time") do={
      :set CleanupInterval 1h;
    }

    :local TimeSinceCleanup ([/system clock get time] - $LastCleanupTime);
    :if ($TimeSinceCleanup >= $CleanupInterval) do={
      :if ([:typeof $AutoCleanupMessages] = "array") do={
        [$AutoCleanupMessages];
        :set LastCleanupTime [/system clock get time];
      }
    }
  }

  :set ExitOK true;
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Script failed: " . $Err);
  }
}
