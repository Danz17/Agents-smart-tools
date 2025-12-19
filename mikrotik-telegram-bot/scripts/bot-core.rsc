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
            $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%5D") as-value ]->"data");
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
  
  :foreach Update in=($JSON->"result") do={
    :set UpdateID ($Update->"update_id");
    :log debug ($ScriptName . " - Processing update " . $UpdateID);

    :local Message ($Update->"message");
    :local IsAnyReply ([:typeof ($Message->"reply_to_message")] = "array");
    :local IsMyReply ($TelegramMessageIDs->[:tostr ($Message->"reply_to_message"->"message_id")]);
    
    :if (($IsMyReply = 1 || $TelegramChatOffset->0 > 0 || $Uptime > 5m) && $UpdateID >= $TelegramChatOffset->2) do={
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
          $SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="⚡ TxMTC"; \
            message=("Hey " . ($From->"first_name") . "! Online & " . $ActiveStatus . " | /help") });
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
            "Activate & send any RouterOS command\n\n" . \
            "🛡️ *Security:*\n" . \
            "Rate: " . $CommandRateLimit . "/min | `CONFIRM code`\n\n" . \
            "─── by P̷h̷e̷n̷i̷x̷");

          $SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="⚡ TxMTC | Help"; message=$HelpText });
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
        :if ($Done = false && ($IsMyReply = 1 || ($IsAnyReply = false && \
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
            # Process custom command aliases
            :if ([:typeof $ProcessCustomCommand] = "array") do={
              :set Command [$ProcessCustomCommand $Command];
            }
            
            # Check dangerous commands blocklist
            :if ([:typeof $IsDangerousCommand] = "array" && [$IsDangerousCommand $Command] = true) do={
              $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
                replyto=($Message->"message_id"); threadid=$ThreadId; \
                subject="⚡ TxMTC | Blocked"; \
                message=("This command is blocked for security reasons.\n\nCommand: " . $Command) });
              :log warning ($ScriptName . " - Blocked command: " . $Command);
              :set Done true;
            }
            
            # Check whitelist
            :if ($Done = false && [:typeof $CheckWhitelist] = "array" && [$CheckWhitelist $Command] = false) do={
              $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
                replyto=($Message->"message_id"); threadid=$ThreadId; \
                subject="⚡ TxMTC | Not Allowed"; \
                message=("This command is not in the whitelist.\n\nCommand: " . $Command) });
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
            $SendTelegram2 ({ chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚡ TxMTC | Confirm?"; \
              message=("This command requires confirmation:\n\n" . \
                "Command: `" . $Command . "`\n\n" . \
                "To confirm, send:\n`CONFIRM " . $ConfirmCode . "`\n\n" . \
                "This code expires in 5 minutes.") });
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
              
              :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={
                :set State "❌ Command failed with an error!\n\n";
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
              
              $SendTelegram2 ({ chatid=($Chat->"id"); silent=true; \
                replyto=($Message->"message_id"); threadid=$ThreadId; \
                subject="⚡ TxMTC | Result"; \
                message=("⚙️ Command:\n" . $Command . "\n\n" . $State . $OutputText) });
              
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
    
  :set ExitOK true;
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Script failed: " . $Err);
  }
}
