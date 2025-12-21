#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Core Script - Main bot loop
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
# requires device-mode, fetch
#
# Dependencies: bot-config, modules/shared-functions, modules/telegram-api, modules/security

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded. Run bot-config first."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # ============================================================================
  # LOAD MODULES
  # ============================================================================

  # Import shared functions module
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

  # Import script registry module
  :global ScriptRegistryLoaded;
  :if ($ScriptRegistryLoaded != true) do={
    :onerror ModErr { /system script run "modules/script-registry"; } do={
      :log warning ($ScriptName . " - Could not load script-registry module");
    }
  }

  # Import interactive menu module
  :global InteractiveMenuLoaded;
  :if ($InteractiveMenuLoaded != true) do={
    :onerror ModErr { /system script run "modules/interactive-menu"; } do={
      :log warning ($ScriptName . " - Could not load interactive-menu module");
    }
  }

  # Import user settings module
  :global UserSettingsLoaded;
  :if ($UserSettingsLoaded != true) do={
    :onerror ModErr { /system script run "modules/user-settings"; } do={
      :log warning ($ScriptName . " - Could not load user-settings module");
    }
  }

  # Import script discovery module
  :global ScriptDiscoveryLoaded;
  :if ($ScriptDiscoveryLoaded != true) do={
    :onerror ModErr { /system script run "modules/script-discovery"; } do={
      :log warning ($ScriptName . " - Could not load script-discovery module");
    }
  }

  # Import Claude relay module (Python service mode)
  :global ClaudeRelayLoaded;
  :if ($ClaudeRelayLoaded != true) do={
    :onerror ModErr { /system script run "modules/claude-relay"; } do={
      :log warning ($ScriptName . " - Could not load claude-relay module");
    }
  }

  # Import Claude relay native module (Direct API mode)
  :global ClaudeRelayNativeLoaded;
  :global ClaudeRelayNativeEnabled;
  :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true) do={
    :if ($ClaudeRelayNativeLoaded != true) do={
      :onerror ModErr { /system script run "modules/claude-relay-native"; } do={
        :log warning ($ScriptName . " - Could not load claude-relay-native module");
      }
    }
  }

  # ============================================================================
  # IMPORT GLOBALS
  # ============================================================================

  # Configuration variables
  :global Identity;
  :global IdentityExtra;
  :global TelegramChatActive;
  :global TelegramChatGroups;
  :global TelegramChatId;
  :global TelegramChatIdsTrusted;
  :global TelegramChatOffset;
  :global TelegramChatRunTime;
  :global TelegramMessageIDs;
  :global TelegramRandomDelay;
  :global TelegramThreadId;
  :global TelegramTokenId;
  :global TelegramQueue;
  :global CustomCommands;
  :global CommandRateLimit;
  :global LogAllCommands;
  :global NotifyUntrustedAttempts;
  :global BlockDuration;
  
  # Imported functions from modules
  :global SendTelegram2;
  :global FetchTelegramUpdates;
  :global CertificateAvailable;
  :global ValidateSyntax;
  :global CheckRateLimit;
  :global CheckWhitelist;
  :global RequiresConfirmation;
  :global StorePendingConfirmation;
  :global CheckConfirmation;
  :global IsUserBlocked;
  :global RecordFailedAttempt;
  :global IsUserTrusted;
  :global IsDangerousCommand;
  :global ProcessCustomCommand;
  :global ShowMainMenu;
  :global HandleCallbackQuery;
  :global ListScriptsByCategory;
  :global GetCategories;
  :global InstallScriptFromRegistry;
  :global SearchScripts;
  :global FormatUserSettings;
  :global GetUserSettings;
  :global SetUserSetting;
  :global AutoCleanupMessages;
  :global CleanupOldMessages;
  :global GetUserNotificationStyle;
  :global ProcessSmartCommand;
  :global ProcessSmartCommandNative;
  :global ClaudeRelayAvailable;
  :global GetErrorSuggestions;
  :global ClaudeRelayInitCloud;
  :global SendTelegramWithKeyboard;
  :global CreateInlineKeyboard;
  :global CreateCommandButtons;
  :global EditTelegramMessage;
  :global SendOrUpdateMessage;
  
  # ============================================================================
  # HELPER: SEND BOT REPLY WITH BUTTONS
  # ============================================================================
  
  :global SendBotReplyWithButtons do={
    :local ChatId [ :tostr $1 ];
    :local MessageText [ :tostr $2 ];
    :local Buttons $3;  # Array of button rows
    :local ThreadId [ :tostr $4 ];
    :local ReplyTo [ :tostr $5 ];
    
    :global SendTelegramWithKeyboard;
    :global CreateInlineKeyboard;
    
    :if ([:typeof $SendTelegramWithKeyboard] != "array") do={
      :global SendTelegram2;
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

  :if ([:typeof $TelegramChatOffset] != "array") do={
    :set TelegramChatOffset { 0; 0; 0 };
  }
  :if ([:typeof $TelegramRandomDelay] != "num") do={
    :set TelegramRandomDelay 0;
  }
  :if ([:typeof $TelegramMessageIDs] = "nothing") do={
    :set TelegramMessageIDs ({});
  }

  # Load persisted state on startup
  :local StateFile "tmpfs/bot-state-runtime.txt";
  :onerror LoadStateErr {
    :if ([:len [/file find name=$StateFile]] > 0) do={
      :local StateData ([/file get $StateFile contents]);
      :if ([:len $StateData] > 0) do={
        :local StateJSON [ :deserialize from=json $StateData ];
        :if ([:typeof ($StateJSON->"offset")] = "array") do={
          :set TelegramChatOffset ($StateJSON->"offset");
        }
        :log debug ($ScriptName . " - Loaded persisted state");
      }
    }
  } do={
    :log debug ($ScriptName . " - No persisted state found (first run)");
  }

  # Initialize cloud connection if enabled
  :global ClaudeRelayUseCloud;
  :if ([:typeof $ClaudeRelayUseCloud] = "bool" && $ClaudeRelayUseCloud = true) do={
    :if ([:typeof $ClaudeRelayInitCloud] = "array") do={
      :local CloudResult [$ClaudeRelayInitCloud];
      :if (($CloudResult->"success") = true) do={
        :log info ($ScriptName . " - Cloud connection established: " . ($CloudResult->"url"));
      } else={
        :log warning ($ScriptName . " - Cloud connection failed: " . ($CloudResult->"error"));
      }
    }
  }

  # ============================================================================
  # RANDOM DELAY (prevent simultaneous polling)
  # ============================================================================

  :if ($TelegramRandomDelay > 0) do={
    :local RndDelay [:rndnum from=0 to=$TelegramRandomDelay];
    :delay ($RndDelay . "s");
  }

  # ============================================================================
  # FETCH UPDATES FROM TELEGRAM
  # ============================================================================

  :local JSON;
  :if ([:typeof $FetchTelegramUpdates] = "array") do={
    :set JSON [$FetchTelegramUpdates];
  } else={
    # Fallback if module not loaded
    :local Data false;
    :for I from=1 to=4 do={
      :if ($Data = false) do={
        :onerror FetchErr {
          :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user \
            ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=" . \
            $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D") as-value ]->"data");
        } do={
          :if ($I < 4) do={ :delay (($I * $I) . "s"); }
        }
      }
    }
    :if ($Data != false) do={
      :set JSON [ :deserialize from=json $Data ];
    }
  }

  :if ([:typeof $JSON] = "nothing") do={
    :log warning ($ScriptName . " - Failed getting updates");
    :set ExitOK true;
    :error false;
  }

  # ============================================================================
  # PROCESS UPDATES
  # ============================================================================

  :local UpdateID 0;
  :local Uptime [ /system/resource/get uptime ];
  :local Results ($JSON->"result");
  :local QueueLen [:len $Results];

  # Queue management: if more than 3 pending messages, offer to clear
  :if ($QueueLen > 3) do={
    :local LastIdx ($QueueLen - 1);
    :local LastUpdate ($Results->$LastIdx);
    :local LastMessage ($LastUpdate->"message");
    :local LastChat ($LastMessage->"chat");
    :local LastCommand ($LastMessage->"text");
    :local LastThreadId "";
    :if (($LastMessage->"is_topic_message") = true) do={
      :set LastThreadId ($LastMessage->"message_thread_id");
    }

    # Check if latest message is the clear command
    :if ($LastCommand = "/clear" || $LastCommand = "/clearqueue") do={
      :local LastUpdateID ($LastUpdate->"update_id");
      :set TelegramChatOffset ({ ($LastUpdateID + 1); ($LastUpdateID + 1); ($LastUpdateID + 1) });
      $SendTelegram2 ({ chatid=($LastChat->"id"); silent=false; \
        replyto=($LastMessage->"message_id"); threadid=$LastThreadId; \
        subject="\E2\9A\A1 TxMTC | Queue Cleared"; \
        message=("\F0\9F\97\91 Cleared " . ($QueueLen - 1) . " pending messages.\nReady for new commands!") });
      :log info ($ScriptName . " - Queue cleared by user, skipped " . ($QueueLen - 1) . " messages");
      :set ExitOK true;
      :error false;
    }

    # Not a clear command - notify about queue and process only latest
    $SendTelegram2 ({ chatid=($LastChat->"id"); silent=true; threadid=$LastThreadId; \
      subject="\E2\9A\A1 TxMTC | Queue Notice"; \
      message=("\F0\9F\93\AC " . $QueueLen . " pending messages in queue.\nProcessing latest only.\n\nSend `/clear` to empty queue.") });
    :log info ($ScriptName . " - Large queue (" . $QueueLen . "), processing latest only");

    # Process only the latest message
    :set Results ({ $LastUpdate });
  }

  :foreach Update in=$Results do={
    :set UpdateID ($Update->"update_id");
    :log debug ($ScriptName . " - Processing update " . $UpdateID);

      # Handle callback queries (inline keyboard button presses)
      :local CallbackQuery ($Update->"callback_query");
      :if ([:typeof $CallbackQuery] = "array") do={
        :local CallbackData ($CallbackQuery->"data");
        :local CallbackChat ($CallbackQuery->"message"->"chat");
        :local CallbackMsgId ($CallbackQuery->"message"->"message_id");
        :local CallbackFrom ($CallbackQuery->"from");
        :local CallbackId ($CallbackQuery->"id");
        :local ThreadId "";
        :if (($CallbackQuery->"message"->"is_topic_message") = true) do={
          :set ThreadId ($CallbackQuery->"message"->"message_thread_id");
        }
        
        :local CallbackChatId [:tostr ($CallbackChat->"id")];
        :local CallbackFromId [:tostr ($CallbackFrom->"id")];
        
        # Check if user is trusted
        :local Trusted false;
        :if ([:typeof $IsUserTrusted] = "array") do={
          :set Trusted [$IsUserTrusted $CallbackFromId $CallbackChatId];
        } else={
          :if ($CallbackFromId = $TelegramChatId || $CallbackChatId = $TelegramChatId) do={
            :set Trusted true;
          }
        }
        
        :if ($Trusted = true) do={
          # Handle command callbacks (cmd:command)
          :if ($CallbackData ~ "^cmd:") do={
            :local CmdToExecute [:pick $CallbackData 4 [:len $CallbackData]];
            :log info ($ScriptName . " - Command button pressed: " . $CmdToExecute);
            # Answer callback query
            :global AnswerCallbackQuery;
            :if ([:typeof $AnswerCallbackQuery] = "array") do={
              [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
            }
            # Process as if user sent the command
            :set Command $CmdToExecute;
            :set Message ($CallbackQuery->"message");
            :set Chat ($Message->"chat");
            :set From ($CallbackQuery->"from");
            :set IsMyReply true;
            :set IsAnyReply false;
            # Fall through to process command (don't continue)
          } else={
            # Handle monitoring callbacks
            :if ($CallbackData = "monitoring:refresh") do={
              :global AnswerCallbackQuery;
              :if ([:typeof $AnswerCallbackQuery] = "array") do={
                [$AnswerCallbackQuery [:tostr $CallbackId] "Refreshing monitoring..." false];
              }
              # Execute monitoring script immediately
              :onerror MonErr {
                /system script run "modules/monitoring";
                :log info ($ScriptName . " - Monitoring refresh triggered");
              } do={
                :log warning ($ScriptName . " - Failed to run monitoring: " . $MonErr);
              }
              :continue;
            }
            
            :if ($CallbackData = "monitoring:devices") do={
              :global AnswerCallbackQuery;
              :global GetConnectedDevices;
              :global SendTelegram2;
              :if ([:typeof $AnswerCallbackQuery] = "array") do={
                [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
              }
              :if ([:typeof $GetConnectedDevices] = "array") do={
                :local DevicesMsg [$GetConnectedDevices];
                $SendTelegram2 ({ chatid=$CallbackChatId; silent=false; subject="📱 Connected Devices"; message=$DevicesMsg; threadid=$ThreadId });
              } else={
                $SendTelegram2 ({ chatid=$CallbackChatId; silent=false; subject="📱 Connected Devices"; message="Connected devices function not available."; threadid=$ThreadId });
              }
              :continue;
            }
            
            :if ($CallbackData = "monitoring:command") do={
              :global AnswerCallbackQuery;
              :if ([:typeof $AnswerCallbackQuery] = "array") do={
                [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
              }
              # Send prompt message asking user to type command
              $SendTelegram2 ({ chatid=$CallbackChatId; silent=false; subject="⚙️ RouterOS Command"; \
                message=("Type your RouterOS command now\\.\n\nExample:\n`/interface print`\n`/ip dhcp-server lease print`\n\nOr activate device first:\n`! " . $Identity . "`\n\nThen send your command\\."); \
                threadid=$ThreadId });
              :continue;
            }
            
            # Handle other callbacks via interactive menu
            :if ([:typeof $HandleCallbackQuery] = "array") do={
              [$HandleCallbackQuery $CallbackData $CallbackChatId [:tostr $CallbackMsgId] $ThreadId [:tostr $CallbackId]];
            }
            :continue;
          }
        } else={
          :continue;
        }
      }

    :local Message ($Update->"message");
    :if ([:typeof $Message] != "array") do={
      :continue;
    }
    
    :local IsAnyReply ([:typeof ($Message->"reply_to_message")] = "array");
    :local IsMyReply false;
    :if ($IsAnyReply = true) do={
      :local ReplyMsgId [:tostr ($Message->"reply_to_message"->"message_id")];
      :if ([:typeof ($TelegramMessageIDs->$ReplyMsgId)] != "nothing" && \
           ($TelegramMessageIDs->$ReplyMsgId) = 1) do={
        :set IsMyReply true;
      }
    }
    
    # Process message if update_id is >= current offset
    # (Always process new messages, regardless of reply status or uptime)
    :if ($UpdateID >= $TelegramChatOffset->2) do={
      :local Chat ($Message->"chat");
      :local From ($Message->"from");
      :local Command ($Message->"text");
      :local ThreadId "";
      :if (($Message->"is_topic_message") = true) do={
        :set ThreadId ($Message->"message_thread_id");
      }

      # Check if user is trusted
      :local FromId [:tostr ($From->"id")];
      :local ChatIdStr [:tostr ($Chat->"id")];
      :local Trusted false;
      
      :if ([:typeof $IsUserTrusted] = "array") do={
        :set Trusted [$IsUserTrusted $FromId $ChatIdStr];
      } else={
        # Fallback trust check
        :if ($FromId = $TelegramChatId || $ChatIdStr = $TelegramChatId) do={
          :set Trusted true;
        }
      }

      :if ($Trusted = true) do={
        :local Done false;
        
        # Check if user is blocked
        :if ([:typeof $IsUserBlocked] = "array" && [$IsUserBlocked $FromId] = true) do={
          :log warning ($ScriptName . " - Blocked user " . $FromId . " attempted access");
          $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="⚡ TxMTC | Blocked"; \
            message=("Temporarily blocked - too many failed attempts.\nWait " . $BlockDuration . " min.") });
          :set Done true;
        }
        
        # Handle "?" - device query
        :if ($Done = false && $Command = "?") do={
          :log info ($ScriptName . " - Status query from update " . $UpdateID);
          :local ActiveStatus "passive";
          :if ($TelegramChatActive = true) do={ :set ActiveStatus "active"; }
          :local StatusMsg ("Hey " . ($From->"first_name") . "\\! Online \\& " . $ActiveStatus . " | /help");
          :local CommonCmds ({{"/status"; "/interfaces"; "/dhcp"; "/logs"}});
          :local CommonButtons [$CreateCommandButtons $CommonCmds];
          :local KeyboardJson [$CreateInlineKeyboard $CommonButtons];
          [$SendTelegramWithKeyboard [:tostr ($Chat->"id")] $StatusMsg $KeyboardJson $ThreadId];
          :set Done true;
        }
        
        # Handle "!" - activation command
        :if ($Done = false && [:pick $Command 0 1] = "!") do={
          :local ActivationPattern ("^! *(" . $Identity . "|@" . $TelegramChatGroups . ")\$");
          :if ($Command ~ $ActivationPattern) do={
            :set TelegramChatActive true;
          } else={
            :set TelegramChatActive false;
          }
          :local StatusText "passive";
          :if ($TelegramChatActive = true) do={ :set StatusText "active"; }
          :log info ($ScriptName . " - Now " . $StatusText . " from update " . $UpdateID);
          :set Done true;
        }
        
        # Handle /help command
        :if ($Done = false && $Command = "/help") do={
          :local HelpText ("*⚡ TxMTC v2.0*\n\n" . \
            "📱 *Control:*\n" . \
            "`?` - Status | `! identity` - Activate\n\n" . \
            "📊 *Info:*\n" . \
            "`/status` `/interfaces` `/dhcp` `/logs` `/wireless`\n\n" . \
            "💾 *Manage:*\n" . \
            "`/backup` `/update`\n\n" . \
            "⚙️ *Execute:*\n" . \
            "Activate & send any RouterOS command\n" . \
            ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true ? "🤖 *Smart Commands:*\nNatural language (e.g., \"show interfaces\")\n\n" : "") . \
            "🛡️ *Security:*\n" . \
            "Rate: " . $CommandRateLimit . "/min | `CONFIRM code`\n\n" . \
            "🎮 *Interactive:*\n" . \
            "`/menu` - Interactive menu\n" . \
            "`/modules` - Install/manage modules\n" . \
            "`/scripts` - List available scripts\n" . \
            "`/settings` - User preferences\n" . \
            "`/cleanup` - Clean old messages\n\n" . \
            "─── by P̷h̷e̷n̷i̷x̷");

          :local HelpCmds ({{"/status"; "/interfaces"; "/dhcp"; "/logs"; "/menu"; "/modules"}});
          :local HelpButtons [$CreateCommandButtons $HelpCmds];
          [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $HelpText $HelpButtons $ThreadId [:tostr ($Message->"message_id")]];
          :set Done true;
        }
        
        # Handle /monitoring-settings command
        :if ($Done = false && $Command = "/monitoring-settings") do={
          :global ShowMonitoringSettings;
          :if ([:typeof $ShowMonitoringSettings] = "array") do={
            [$ShowMonitoringSettings [:tostr ($Chat->"id")] "0" $ThreadId];
            :set Done true;
          } else={
            :local ErrorMsg "Monitoring settings menu not available\\.";
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ErrorMsg ({}) $ThreadId [:tostr ($Message->"message_id")]];
            :set Done true;
          }
        }
        
        # Handle /menu command
        :if ($Done = false && $Command = "/menu") do={
          :global EnableInteractiveMenus;
          :if ([:typeof $EnableInteractiveMenus] = "bool" && $EnableInteractiveMenus = true && \
               [:typeof $ShowMainMenu] = "array") do={
            [$ShowMainMenu [:tostr ($Chat->"id")] "0" $ThreadId];
            :set Done true;
          } else={
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚡ TxMTC | Menu"; \
              message="Interactive menus are disabled. Use `/scripts` to list available scripts." });
            :set Done true;
          }
        }
        
        # Handle /scripts command
        :if ($Done = false && $Command ~ "^/scripts") do={
          :global ToLower;
          :global Capitalize;
          :local Category "";
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
          :if ([:len $CurrentPart] > 0) do={
            :set ($CmdParts->[:len $CmdParts]) $CurrentPart;
          }
          :if ([:len $CmdParts] > 1) do={
            :set Category [$ToLower ($CmdParts->1)];
          }

          :if ([:len $Category] > 0 && [:typeof $ListScriptsByCategory] = "array") do={
            :local Scripts [$ListScriptsByCategory $Category];
            :local ScriptList ("*Scripts in " . [$Capitalize $Category] . "*\n\n");
            :if ([:len $Scripts] > 0) do={
              :foreach ScriptId,ScriptData in=$Scripts do={
                :set ScriptList ($ScriptList . "• " . ($ScriptData->"name") . "\n");
                :if ([:len ($ScriptData->"description")] > 0) do={
                  :set ScriptList ($ScriptList . "  " . ($ScriptData->"description") . "\n");
                }
                :set ScriptList ($ScriptList . "\n");
              }
            } else={
              :set ScriptList ($ScriptList . "No scripts in this category.");
            }
            :local ScriptCmds ({{"/menu"; "/modules"; "/help"}});
            :local ScriptButtons [$CreateCommandButtons $ScriptCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ScriptList $ScriptButtons $ThreadId [:tostr ($Message->"message_id")]];
          } else={
            :local Categories [$GetCategories];
            :local CatList ("*Available Categories:*\n\n");
            :foreach Cat in=$Categories do={
              :set CatList ($CatList . "• " . [$Capitalize $Cat] . "\n");
            }
            :set CatList ($CatList . "\nUse `/scripts <category>` to list scripts.");
            :local CatCmds ({{"/menu"; "/modules"; "/help"}});
            :local CatButtons [$CreateCommandButtons $CatCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $CatList $CatButtons $ThreadId [:tostr ($Message->"message_id")]];
          }
          :set Done true;
        }
        
        # Handle /modules command (interactive installer menu)
        :if ($Done = false && ($Command = "/modules" || $Command = "/install")) do={
          :global InteractiveInstallerLoaded;
          :if ($InteractiveInstallerLoaded != true) do={
            :onerror e { /system script run "modules/interactive-installer"; } do={}
          }
          :global GenerateInstallerMenu;
          :global CreateInlineKeyboard;
          :global SendTelegramWithKeyboard;
          
          :if ([:typeof $GenerateInstallerMenu] = "array") do={
            :local Menu [$GenerateInstallerMenu];
            :local MsgText ($Menu->"message");
            :local Keyboard ($Menu->"keyboard");
            :local KeyboardJson [$CreateInlineKeyboard $Keyboard];
            
            [$SendTelegramWithKeyboard (:tostr ($Chat->"id")) $MsgText $KeyboardJson $ThreadId];
          } else={
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=true;               replyto=($Message->"message_id"); threadid=$ThreadId;               subject="TxMTC | Modules";               message="Interactive installer not available. Use /scripts to view available modules." });
          }
          :set Done true;
        }
        
        # Handle /install <scriptid> command
        :if ($Done = false && $Command ~ "^/install ") do={
          :local ScriptId [:pick $Command 8 [:len $Command]];
          :while ([:pick $ScriptId 0 1] = " ") do={
            :set ScriptId [:pick $ScriptId 1 [:len $ScriptId]];
          }
          :if ([:len $ScriptId] > 0 && [:typeof $InstallScriptFromRegistry] = "array") do={
            :local Result [$InstallScriptFromRegistry $ScriptId];
            :if (($Result->"success") = true) do={
            :local InstallMsg ("✅ " . ($Result->"message"));
            :local InstallCmds ({{"/modules"; "/scripts"; "/menu"}});
            :local InstallButtons [$CreateCommandButtons $InstallCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $InstallMsg $InstallButtons $ThreadId [:tostr ($Message->"message_id")]];
          } else={
            :local ErrorMsg ("❌ Installation failed: " . ($Result->"error"));
            :local ErrorCmds ({{"/modules"; "/scripts"; "/help"}});
            :local ErrorButtons [$CreateCommandButtons $ErrorCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ErrorMsg $ErrorButtons $ThreadId [:tostr ($Message->"message_id")]];
            }
            :set Done true;
          }
        }
        
        # Handle /settings command
        :if ($Done = false && $Command = "/settings") do={
          :if ([:typeof $FormatUserSettings] = "array") do={
            :local SettingsText [$FormatUserSettings [:tostr ($Chat->"id")]];
            :local SettingsCmds ({{"/menu"; "/help"; "/cleanup"}});
            :local SettingsButtons [$CreateCommandButtons $SettingsCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $SettingsText $SettingsButtons $ThreadId [:tostr ($Message->"message_id")]];
          } else={
            :local ErrorMsg "Settings module not loaded\\.";
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ErrorMsg ({}) $ThreadId [:tostr ($Message->"message_id")]];
          }
          :set Done true;
        }
        
        # Handle /monitor-interfaces command
        :if ($Done = false && $Command ~ "^/monitor-interfaces") do={
          :global AddMonitoredInterface;
          :global RemoveMonitoredInterface;
          :global GetMonitoredInterfaces;
          :global ListAvailableInterfaces;
          :global MonitorInterfaces;
          
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
          
          :local Action "";
          :local InterfaceName "";
          :if ([:len $CmdParts] > 1) do={ :set Action ($CmdParts->1); }
          :if ([:len $CmdParts] > 2) do={ :set InterfaceName ($CmdParts->2); }
          
          :local ResponseMsg "";
          :if ($Action = "add" && [:len $InterfaceName] > 0) do={
            :if ([:typeof $AddMonitoredInterface] = "array") do={
              :if ([$AddMonitoredInterface $InterfaceName] = true) do={
                :set ResponseMsg ("✅ Added *" . $InterfaceName . "* to monitored interfaces\\.\n\nCurrent list: `" . $MonitorInterfaces . "`");
              } else={
                :set ResponseMsg ("⚠️ Interface *" . $InterfaceName . "* is already monitored\\.\n\nCurrent list: `" . $MonitorInterfaces . "`");
              }
            } else={
              :set ResponseMsg "❌ Interface management functions not available\\.";
            }
          } else={
            :if ($Action = "remove" && [:len $InterfaceName] > 0) do={
              :if ([:typeof $RemoveMonitoredInterface] = "array") do={
                :if ([$RemoveMonitoredInterface $InterfaceName] = true) do={
                  :set ResponseMsg ("✅ Removed *" . $InterfaceName . "* from monitored interfaces\\.\n\nCurrent list: `" . $MonitorInterfaces . "`");
                } else={
                  :set ResponseMsg ("⚠️ Interface *" . $InterfaceName . "* is not in the monitored list\\.\n\nCurrent list: `" . $MonitorInterfaces . "`");
                }
              } else={
                :set ResponseMsg "❌ Interface management functions not available\\.";
              }
            } else={
              :if ($Action = "list") do={
                :if ([:typeof $GetMonitoredInterfaces] = "array") do={
                  :local MonitoredList [$GetMonitoredInterfaces];
                  :set ResponseMsg ("📋 *Monitored Interfaces:*\n\n");
                  :foreach Int in=$MonitoredList do={
                    :set ResponseMsg ($ResponseMsg . "• `" . $Int . "`\n");
                  }
                  :if ([:len $MonitoredList] = 0) do={
                    :set ResponseMsg ($ResponseMsg . "_No interfaces configured_");
                  }
                } else={
                  :set ResponseMsg ("📋 *Monitored Interfaces:*\n\n`" . $MonitorInterfaces . "`");
                }
              } else={
                :set ResponseMsg ("📋 *Monitor Interfaces*\n\n" . \
                  "Usage:\n" . \
                  "`/monitor-interfaces add <interface>`\n" . \
                  "`/monitor-interfaces remove <interface>`\n" . \
                  "`/monitor-interfaces list`\n\n" . \
                  "Current: `" . $MonitorInterfaces . "`");
              }
            }
          }
          
          :local InterfaceCmds ({{"/monitor-interfaces list"; "/settings"; "/help"}});
          :local InterfaceButtons [$CreateCommandButtons $InterfaceCmds];
          [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ResponseMsg $InterfaceButtons $ThreadId [:tostr ($Message->"message_id")]];
          :set Done true;
        }
        
        # Handle /cleanup command
        :if ($Done = false && $Command = "/cleanup") do={
          :global MessageRetentionPeriod;
          :global KeepCriticalMessages;
          :if ([:typeof $MessageRetentionPeriod] != "time") do={
            :set MessageRetentionPeriod 24h;
          }
          :if ([:typeof $KeepCriticalMessages] != "bool") do={
            :set KeepCriticalMessages true;
          }
          :if ([:typeof $CleanupOldMessages] = "array") do={
            :local Deleted [$CleanupOldMessages [:tostr ($Chat->"id")] $MessageRetentionPeriod $KeepCriticalMessages];
            :local CleanupMsg ("🧹 Cleaned up " . $Deleted . " old message\\(s\\)");
            :local CleanupCmds ({{"/menu"; "/help"; "/settings"}});
            :local CleanupButtons [$CreateCommandButtons $CleanupCmds];
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $CleanupMsg $CleanupButtons $ThreadId [:tostr ($Message->"message_id")]];
          } else={
            :local ErrorMsg "Message cleanup not available\\.";
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ErrorMsg ({}) $ThreadId [:tostr ($Message->"message_id")]];
          }
          :set Done true;
        }
        
        # Handle confirmation code (case-insensitive)
        :if ($Done = false && $Command ~ "^[Cc][Oo][Nn][Ff][Ii][Rr][Mm] [A-Za-z0-9]+\$") do={
          :local ConfirmCode [:pick $Command 8 [:len $Command]];
          :local ConfirmedCmd "";
          :if ([:typeof $CheckConfirmation] = "array") do={
            :set ConfirmedCmd [$CheckConfirmation $FromId $ConfirmCode];
          }
          
          :if ([:len $ConfirmedCmd] > 0) do={
            :log info ($ScriptName . " - User " . $FromId . " confirmed: " . $ConfirmedCmd);
            :set Command $ConfirmedCmd;
          } else={
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚡ TxMTC | Invalid"; \
              message="Invalid or expired confirmation code.\nPlease request the command again." });
            :set Done true;
          }
        }
        
        # Handle command execution
        # Execute if: reply to bot message OR (not a reply AND bot is active)
        :if ($Done = false && ($IsMyReply = true || ($IsAnyReply = false && \
             $TelegramChatActive = true)) && [:len $Command] > 0) do={
          
          # Check rate limit
          :if ([:typeof $CheckRateLimit] = "array" && [$CheckRateLimit $FromId] = false) do={
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚡ TxMTC | Rate Limit"; \
              message=("You are sending commands too fast.\nLimit: " . $CommandRateLimit . " commands per minute.") });
            :set Done true;
          }
          
          :if ($Done = false) do={
            # Process smart commands via Claude relay (if enabled and command looks like natural language)
            :global ClaudeRelayEnabled;
            :global ClaudeRelayNativeEnabled;
            :global ClaudeRelayAutoExecute;
            :local IsSmartCommand false;
            :local OriginalSmartCommand "";
            
            # Check if either Python service mode or native mode is enabled
            :local UseClaude false;
            :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true) do={
              :set UseClaude true;
            } else={
              :if ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true) do={
                :set UseClaude true;
              }
            }
            
            :if ($UseClaude = true) do={
              # Detect smart commands: not starting with "/" or contains natural language patterns
              :if ([:pick $Command 0 1] != "/" || $Command ~ "^(show|block|unblock|what|how|list|get|find|check)") do={
                :set OriginalSmartCommand $Command;
                :local SmartResult ({success=false});
                
                # Try native mode first (direct API), then fall back to Python service
                :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true && \
                     [:typeof $ProcessSmartCommandNative] = "array") do={
                  :set SmartResult [$ProcessSmartCommandNative $Command];
                } else={
                  :if ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true && \
                       [:typeof $ProcessSmartCommand] = "array") do={
                    :set SmartResult [$ProcessSmartCommand $Command];
                  }
                }
                
                :if (($SmartResult->"success") = true) do={
                  :set Command ($SmartResult->"routeros_command");
                  :set IsSmartCommand true;
                  :log info ($ScriptName . " - Smart command processed: \"" . $OriginalSmartCommand . "\" -> \"" . $Command . "\"");
                  
                  # If auto-execute is enabled, show the translation and proceed
                  :if ([:typeof $ClaudeRelayAutoExecute] = "bool" && $ClaudeRelayAutoExecute = true) do={
                    $SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
                      replyto=($Message->"message_id"); threadid=$ThreadId; \
                      subject="⚡ TxMTC | Smart Command"; \
                      message=("🤖 Translated:\n`" . $OriginalSmartCommand . "`\n\n→ `" . $Command . "`\n\nExecuting...") });
                  }
                } else={
                  # Smart command processing failed, fall back to direct execution
                  :local ErrorMsg ($SmartResult->"error");
                  :log warning ($ScriptName . " - Smart command failed: " . $ErrorMsg);
                  $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
                    replyto=($Message->"message_id"); threadid=$ThreadId; \
                    subject="⚡ TxMTC | Smart Command"; \
                    message=("Could not process smart command:\n\n" . $Command . "\n\nError: " . $ErrorMsg . "\n\nTry using RouterOS command syntax instead.") });
                  :set Done true;
                }
              }
            }
            
            # Process custom command aliases (if not already processed as smart command)
            :if ($Done = false && $IsSmartCommand = false && [:typeof $ProcessCustomCommand] = "array") do={
              :set Command [$ProcessCustomCommand $Command];
            }
            
            # Store command message ID for result editing
            :global TelegramMessageHistory;
            :global LoadBotState;
            :if ([:typeof $TelegramMessageHistory] != "array") do={
              :local LoadedHistory [$LoadBotState "message-history"];
              :if ([:typeof $LoadedHistory] = "array") do={
                :set TelegramMessageHistory $LoadedHistory;
              } else={
                :set TelegramMessageHistory ({});
              }
            }
            :local CommandMsgKey ("cmd_" . [:tostr ($Message->"message_id")]);
            :set ($TelegramMessageHistory->$CommandMsgKey) [:tostr ($Message->"message_id")];
            
            # Check dangerous commands blocklist
            :if ([:typeof $IsDangerousCommand] = "array" && [$IsDangerousCommand $Command] = true) do={
              :local BlockedMsg ("This command is blocked for security reasons\\.\n\nCommand: `" . $Command . "`");
              [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $BlockedMsg ({}) $ThreadId [:tostr ($Message->"message_id")]];
              :log warning ($ScriptName . " - Blocked command: " . $Command);
              :set Done true;
            }
            
            # Check whitelist
            :if ($Done = false && [:typeof $CheckWhitelist] = "array" && [$CheckWhitelist $Command] = false) do={
              :local NotAllowedMsg ("This command is not in the whitelist\\.\n\nCommand: `" . $Command . "`");
              [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $NotAllowedMsg ({}) $ThreadId [:tostr ($Message->"message_id")]];
              :log warning ($ScriptName . " - Non-whitelisted command: " . $Command);
              :set Done true;
            }
          }
          
          # Check if command requires confirmation
          :if ($Done = false && [:typeof $RequiresConfirmation] = "array" && [$RequiresConfirmation $Command] = true) do={
            :local ConfirmCode "";
            :if ([:typeof $StorePendingConfirmation] = "array") do={
              :set ConfirmCode [$StorePendingConfirmation $FromId $Command ($Message->"message_id")];
            }
            :local ConfirmMsg ("This command requires confirmation:\n\n" . \
              "Command: `" . $Command . "`\n\n" . \
              "To confirm, send:\n`CONFIRM " . $ConfirmCode . "`\n\n" . \
              "This code expires in 5 minutes.");
            :local ConfirmButtons ({({text="✅ Confirm"; callback_data=("confirm:" . $ConfirmCode)})});
            [$SendBotReplyWithButtons [:tostr ($Chat->"id")] $ConfirmMsg $ConfirmButtons $ThreadId [:tostr ($Message->"message_id")]];
            :log info ($ScriptName . " - Confirmation requested for: " . $Command);
            :set Done true;
          }
          
          :if ($Done = false) do={
            # Log command if enabled
            :if ($LogAllCommands = true) do={
              :log warning ($ScriptName . " - User " . $FromId . " executed: " . $Command);
            }
            
            # Validate syntax
            :local SyntaxValid true;
            :if ([:typeof $ValidateSyntax] = "array") do={
              :set SyntaxValid [$ValidateSyntax $Command];
            } else={
              :onerror SyntaxErr { :parse $Command; } do={ :set SyntaxValid false; }
            }
            
            :if ($SyntaxValid = true) do={
              :local State "";
              :local TmpFile ("tmpfs/telegram-bot-" . $UpdateID);
              
              :log info ($ScriptName . " - Executing: " . $Command);
              :execute script=(":do {\n" . $Command . "\n} on-error={ /file/add name=\"" . $TmpFile . ".failed\" };" . \
                "/file/add name=\"" . $TmpFile . ".done\"") file=($TmpFile . "\00");
              
              # Wait for command completion
              :local WaitTime [:totime $TelegramChatRunTime];
              :local StartTime [/system clock get time];
              :local TimedOut false;
              :while ([:len [/file find name=($TmpFile . ".done")]] = 0 && $TimedOut = false) do={
                :local CurrentTime [/system clock get time];
                :if (($CurrentTime - $StartTime) > $WaitTime) do={
                  :set TimedOut true;
                  :set State "⚠️ Command still running in background.\n\n";
                } else={
                  :delay 500ms;
                }
              }
              
              :local CommandFailed false;
              :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={
                :set State "❌ Command failed with an error!\n\n";
                :set CommandFailed true;
              }
              
              :local Content "";
              :if ([:len [/file find name=$TmpFile]] > 0) do={
                :set Content ([/file/get $TmpFile contents]);
              }
              
              :local OutputText "";
              :if ([:len $Content] > 0) do={
                :set OutputText ("📝 Output:\n" . $Content);
              } else={
                :set OutputText "📝 No output.";
              }
              
              # If command failed and error suggestions are enabled, get suggestions
              :local ErrorSuggestions "";
              :if ($CommandFailed = true && [:typeof $GetErrorSuggestions] = "array") do={
                :global ClaudeRelayErrorSuggestions;
                :if ([:typeof $ClaudeRelayErrorSuggestions] = "bool" && $ClaudeRelayErrorSuggestions = true) do={
                  :local SuggestionResult [$GetErrorSuggestions $Command $State $Content];
                  :if (($SuggestionResult->"success") = true) do={
                    :set ErrorSuggestions ($SuggestionResult->"suggestion");
                    :set OutputText ($OutputText . "\n\n💡 *Suggestion:*\n" . $ErrorSuggestions);
                  }
                }
              }
              
              # Build result message
              :local ResultMsg ("⚙️ Command:\n`" . $Command . "`\n\n" . $State . $OutputText);
              
              # Track command message ID for editing
              :global TelegramMessageHistory;
              :global LoadBotState;
              :global SaveBotState;
              :if ([:typeof $TelegramMessageHistory] != "array") do={
                :local LoadedHistory [$LoadBotState "message-history"];
                :if ([:typeof $LoadedHistory] = "array") do={
                  :set TelegramMessageHistory $LoadedHistory;
                } else={
                  :set TelegramMessageHistory ({});
                }
              }
              
              :local CommandMsgKey ("cmd_" . [:tostr ($Message->"message_id")]);
              :local ExistingCmdMsgId ($TelegramMessageHistory->$CommandMsgKey);
              
              # For short outputs (< 1000 chars), edit original message
              :if ([:len $ResultMsg] < 1000 && [:len $ExistingCmdMsgId] > 0 && $ExistingCmdMsgId != "0") do={
                :local EditResult [$EditTelegramMessage [:tostr ($Chat->"id")] $ExistingCmdMsgId $ResultMsg ""];
                :if ($EditResult = true) do={
                  :log debug ($ScriptName . " - Edited command result message");
                } else={
                  # Message deleted, send new
                  :local NewMsgId [$SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
                    replyto=($Message->"message_id"); threadid=$ThreadId; \
                    subject="⚡ TxMTC | Result"; message=$ResultMsg })];
                  :if ([:len $NewMsgId] > 0) do={
                    :set ($TelegramMessageHistory->$CommandMsgKey) $NewMsgId;
                    [$SaveBotState "message-history" $TelegramMessageHistory];
                  }
                }
              } else={
                # Send new message for long outputs or first time
                :local NewMsgId [$SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
                  replyto=($Message->"message_id"); threadid=$ThreadId; \
                  subject="⚡ TxMTC | Result"; message=$ResultMsg })];
                :if ([:len $NewMsgId] > 0) do={
                  :set ($TelegramMessageHistory->$CommandMsgKey) $NewMsgId;
                  [$SaveBotState "message-history" $TelegramMessageHistory];
                }
              }
              
              # Cleanup temp files
              :if ([:len [/file find name=$TmpFile]] > 0) do={ /file remove $TmpFile; }
              :if ([:len [/file find name=($TmpFile . ".done")]] > 0) do={ /file remove ($TmpFile . ".done"); }
              :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={ /file remove ($TmpFile . ".failed"); }
            } else={
              :log info ($ScriptName . " - Syntax validation failed for update " . $UpdateID);
              $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
                replyto=($Message->"message_id"); threadid=$ThreadId; \
                subject="⚡ TxMTC | Error"; \
                message=("⚙️ Command:\n" . $Command . "\n\n❌ Syntax validation failed!") });
            }
          }
        }
      } else={
        # Untrusted user handling
        :local UsernameText "";
        :if ([:len ($From->"username")] = 0) do={
          :set UsernameText "without username";
        } else={
          :set UsernameText ("'" . ($From->"username") . "'");
        }
        :local MessageText ("Untrusted contact " . $UsernameText . " (ID " . $From->"id" . ")");
        
        :if ($Command ~ ("^! *" . $Identity . "\$")) do={
          :log warning ($ScriptName . " - " . $MessageText . " attempted activation");
          :if ($NotifyUntrustedAttempts = true) do={
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚡ TxMTC | Denied"; message="Not trusted." });
          }
        } else={
          :log info ($ScriptName . " - " . $MessageText);
        }
      }
    } else={
      :log debug ($ScriptName . " - Skipped update " . $UpdateID);
    }
  }

  # ============================================================================
  # UPDATE OFFSET
  # ============================================================================
  
  :local NewOffset;
  :if ($UpdateID >= $TelegramChatOffset->2) do={
    :set NewOffset ($UpdateID + 1);
  } else={
    :set NewOffset ($TelegramChatOffset->2);
  }
  :set TelegramChatOffset ([:pick $TelegramChatOffset 1 3], $NewOffset);
  
  # ============================================================================
  # AUTO CLEANUP (periodic)
  # ============================================================================
  
  :global AutoCleanupEnabled;
  :global CleanupInterval;
  :global LastCleanupTime;
  
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
