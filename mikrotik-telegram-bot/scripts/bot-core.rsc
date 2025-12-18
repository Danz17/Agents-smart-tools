#!rsc by RouterOS
# MikroTik Telegram Bot - Core Script
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
# requires device-mode, fetch
#
# Enhanced Telegram bot with command execution and notifications
# Combines telegram-chat and notification-telegram functionality

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded. Run bot-config first."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # Import configuration variables
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
  :global RequireConfirmation;
  :global ConfirmationRequired;
  :global LogAllCommands;
  :global NotifyUntrustedAttempts;
  :global EnableCommandWhitelist;
  :global CommandWhitelist;
  :global MaxFailedAttempts;
  :global BlockDuration;
  
  # Runtime state variables
  :global CommandRateLimitTracker;
  :global PendingConfirmations;
  :global BlockedUsers;

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Certificate check - simplified to always work
  :local CertificateAvailable do={
    :return true;
  }

  # Escape markdown v2 special characters
  :local EscapeMD do={
    :local Text [ :tostr $1 ];
    :local Mode [ :tostr $2 ];
    
    :local CharacterReplace do={
      :local String [ :tostr $1 ];
      :local Find [ :tostr $2 ];
      :local Replace [ :tostr $3 ];
      :local Result "";
      :local Pos 0;
      
      :while ([:len $String] > 0) do={
        :local NextPos [:find $String $Find $Pos];
        :if ([:typeof $NextPos] = "nil") do={
          :set Result ($Result . [:pick $String $Pos [:len $String]]);
          :set String "";
        } else={
          :set Result ($Result . [:pick $String $Pos $NextPos] . $Replace);
          :set Pos ($NextPos + [:len $Find]);
        }
      }
      :return $Result;
    }

    :local Chars ({ "\\"; "`"; "_"; "*"; "["; "]"; "("; ")"; "~"; ">"; "#"; "+"; "-"; "="; "|"; "{"; "}"; "."; "!" });
    :if ($Mode = "body") do={
      :set Chars ({ "\\"; "`" });
    }
    
    :foreach Char in=$Chars do={
      :set Text [$CharacterReplace $Text $Char ("\\" . $Char)];
    }
    
    :if ($Mode = "body") do={
      :return ("```\n" . $Text . "\n```");
    }
    :return $Text;
  }

  # URL encode
  :local UrlEncode do={
    :local String [ :tostr $1 ];
    :local Result "";
    :for I from=0 to=([:len $String] - 1) do={
      :local Char [:pick $String $I ($I + 1)];
      :if ($Char ~ "[A-Za-z0-9_.~-]") do={
        :set Result ($Result . $Char);
      } else={
        :local CharArray [:toarray $Char];
        :local FirstChar ($CharArray->0);
        :local CharCode [:tonum $FirstChar];
        :if ([:typeof $CharCode] = "num") do={
          :set Result ($Result . ("%" . [:pick "0123456789ABCDEF" ($CharCode / 16) ($CharCode / 16 + 1)] . \
            [:pick "0123456789ABCDEF" ($CharCode % 16) ($CharCode % 16 + 1)]));
        } else={
          :set Result ($Result . $Char);
        }
      }
    }
    :return $Result;
  }

  # Validate syntax - returns true if valid, false if invalid
  :local ValidateSyntax do={
    :local Code [ :tostr $1 ];
    :onerror SyntaxErr {
      :parse $Code;
      :return true;
    } do={
      :return false;
    }
  }

  # Send Telegram message
  :local SendTelegram2 do={
    :local Notification $1;
    
    :global TelegramTokenId;
    :global TelegramChatId;
    :global TelegramThreadId;
    :global TelegramMessageIDs;
    :global TelegramQueue;
    :global Identity;
    :global IdentityExtra;
    
    :local ChatId ([$1 "chatid"]);
    :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
    
    :local ThreadId ([$1 "threadid"]);
    :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
    
    :if ([:typeof $TelegramMessageIDs] = "nothing") do={
      :set TelegramMessageIDs ({});
    }
    
    :local Text ("*__" . [$EscapeMD ("[" . $IdentityExtra . $Identity . "] " . \
      ($Notification->"subject")) "plain"] . "__*\n\n");
    :set Text ($Text . [$EscapeMD ($Notification->"message") "body"]);
    
    :local HTTPData ("chat_id=" . $ChatId . "&disable_notification=" . \
      ($Notification->"silent") . "&reply_to_message_id=" . ($Notification->"replyto") . \
      "&message_thread_id=" . $ThreadId . "&disable_web_page_preview=true&parse_mode=MarkdownV2");
    
    :onerror SendErr {
      :if ([$CertificateAvailable "Go Daddy Root Certificate Authority - G2"] = false) do={
        :log warning ($ScriptName . " - Certificate download failed");
        :error false;
      }
      :local Data ([ /tool/fetch check-certificate=no output=user http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]) as-value ]->"data");
      :set ($TelegramMessageIDs->[ :tostr ([ :deserialize from=json value=$Data ]->"result"->"message_id") ]) 1;
    } do={
      :log info ($ScriptName . " - Message queued: " . $SendErr);
      :if ([:typeof $TelegramQueue] = "nothing") do={
        :set TelegramQueue ({});
      }
      :set ($TelegramQueue->[:len $TelegramQueue]) { tokenid=$TelegramTokenId;
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]) };
    }
  }

  # Get Telegram Chat ID helper
  :local GetTelegramChatId do={
    :global TelegramTokenId;
    
    :if ([$CertificateAvailable "Go Daddy Root Certificate Authority - G2"] = false) do={
      :log warning "Certificate download failed";
      :return false;
    }
    
    :local Data;
    :onerror FetchErr {
      :set Data ([ /tool/fetch check-certificate=no output=user \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=0" . \
        "&allowed_updates=%5B%22message%22%5D") as-value ]->"data");
    } do={
      :log warning ("Fetching data failed: " . $FetchErr);
      :return false;
    }
    
    :local JSON [ :deserialize from=json value=$Data ];
    :local Count [ :len ($JSON->"result") ];
    
    :if ($Count = 0) do={
      :log info "No message received.";
      :return false;
    }
    
    :local Message ($JSON->"result"->($Count - 1)->"message");
    :log info ("The chat id is: " . ($Message->"chat"->"id"));
    :if (($Message->"is_topic_message") = true) do={
      :log info ("The thread id is: " . ($Message->"message_thread_id"));
    }
  }

  # Process custom command aliases
  :local ProcessCustomCommand do={
    :local Command [ :tostr $1 ];
    :global CustomCommands;
    
    # Check if command starts with /
    :if ([:pick $Command 0 1] = "/") do={
      :local CmdName [:pick $Command 1 [:len $Command]];
      :local CmdParts [:toarray $CmdName];
      :local BaseCmd [:pick $CmdParts 0];
      
      :if ([:typeof ($CustomCommands->$BaseCmd)] != "nothing") do={
        :return ($CustomCommands->$BaseCmd);
      }
    }
    :return $Command;
  }

  # ============================================================================
  # RATE LIMITING
  # ============================================================================
  
  :local CheckRateLimit do={
    :local UserId [ :tostr $1 ];
    :global CommandRateLimit;
    :global CommandRateLimitTracker;
    
    # Initialize tracker if needed
    :if ([:typeof $CommandRateLimitTracker] != "array") do={
      :set CommandRateLimitTracker ({});
    }
    
    :local CurrentTime [:timestamp];
    :local UserKey ("user_" . $UserId);
    :local UserData ($CommandRateLimitTracker->$UserKey);
    
    # Clean up old entries (older than 1 minute)
    :if ([:typeof $UserData] = "array") do={
      :local LastTime ($UserData->"time");
      :local TimeDiff ($CurrentTime - $LastTime);
      :if ($TimeDiff > 60s) do={
        :set ($CommandRateLimitTracker->$UserKey) ({count=1; time=$CurrentTime});
        :return true;
      }
      
      :local Count ($UserData->"count");
      :if ($Count >= $CommandRateLimit) do={
        :return false;
      }
      
      :set ($CommandRateLimitTracker->$UserKey) ({count=($Count + 1); time=($UserData->"time")});
      :return true;
    }
    
    # First command from this user
    :set ($CommandRateLimitTracker->$UserKey) ({count=1; time=$CurrentTime});
    :return true;
  }

  # ============================================================================
  # COMMAND WHITELIST CHECK
  # ============================================================================
  
  :local CheckWhitelist do={
    :local Command [ :tostr $1 ];
    :global EnableCommandWhitelist;
    :global CommandWhitelist;
    
    # If whitelist is disabled, allow all
    :if ($EnableCommandWhitelist != true) do={
      :return true;
    }
    
    # Check if command matches any whitelisted command
    :foreach AllowedCmd in=$CommandWhitelist do={
      :if ($Command ~ ("^" . $AllowedCmd)) do={
        :return true;
      }
    }
    
    :return false;
  }

  # ============================================================================
  # CONFIRMATION FLOW
  # ============================================================================
  
  :local RequiresConfirmation do={
    :local Command [ :tostr $1 ];
    :global RequireConfirmation;
    :global ConfirmationRequired;
    
    :if ($RequireConfirmation != true) do={
      :return false;
    }
    
    :foreach DangerousCmd in=$ConfirmationRequired do={
      :if ($Command ~ $DangerousCmd) do={
        :return true;
      }
    }
    
    :return false;
  }
  
  :local StorePendingConfirmation do={
    :local UserId [ :tostr $1 ];
    :local Command [ :tostr $2 ];
    :local MsgId [ :tostr $3 ];
    :global PendingConfirmations;
    
    :if ([:typeof $PendingConfirmations] != "array") do={
      :set PendingConfirmations ({});
    }
    
    :local ConfirmCode [:rndstr length=6 from="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
    :local UserKey ("user_" . $UserId);
    :set ($PendingConfirmations->$UserKey) ({
      command=$Command;
      code=$ConfirmCode;
      msgid=$MsgId;
      time=[:timestamp]
    });
    
    :return $ConfirmCode;
  }
  
  :local CheckConfirmation do={
    :local UserId [ :tostr $1 ];
    :local InputCode [ :tostr $2 ];
    :global PendingConfirmations;
    
    :if ([:typeof $PendingConfirmations] != "array") do={
      :return "";
    }
    
    :local UserKey ("user_" . $UserId);
    :local Pending ($PendingConfirmations->$UserKey);
    
    :if ([:typeof $Pending] != "array") do={
      :return "";
    }
    
    # Check if confirmation is still valid (5 minute timeout)
    :local PendingTime ($Pending->"time");
    :local TimeDiff ([:timestamp] - $PendingTime);
    :if ($TimeDiff > 5m) do={
      :set ($PendingConfirmations->$UserKey) "";
      :return "";
    }
    
    # Check confirmation code
    :if (($Pending->"code") = $InputCode) do={
      :local ConfirmedCmd ($Pending->"command");
      :set ($PendingConfirmations->$UserKey) "";
      :return $ConfirmedCmd;
    }
    
    :return "";
  }

  # ============================================================================
  # USER BLOCKING
  # ============================================================================
  
  :local IsUserBlocked do={
    :local UserId [ :tostr $1 ];
    :global BlockedUsers;
    :global BlockDuration;
    
    :if ([:typeof $BlockedUsers] != "array") do={
      :return false;
    }
    
    :local UserKey ("user_" . $UserId);
    :local BlockData ($BlockedUsers->$UserKey);
    
    :if ([:typeof $BlockData] != "array") do={
      :return false;
    }
    
    :local BlockTime ($BlockData->"time");
    :local TimeDiff ([:timestamp] - $BlockTime);
    :local BlockDur ([:tonum $BlockDuration] * 60s);
    
    :if ($TimeDiff > $BlockDur) do={
      :set ($BlockedUsers->$UserKey) "";
      :return false;
    }
    
    :return true;
  }
  
  :local RecordFailedAttempt do={
    :local UserId [ :tostr $1 ];
    :global BlockedUsers;
    :global MaxFailedAttempts;
    
    :if ([:typeof $BlockedUsers] != "array") do={
      :set BlockedUsers ({});
    }
    
    :local UserKey ("user_" . $UserId);
    :local FailKey ("fails_" . $UserId);
    :local Fails ($BlockedUsers->$FailKey);
    
    :if ([:typeof $Fails] != "num") do={
      :set Fails 0;
    }
    
    :set Fails ($Fails + 1);
    :set ($BlockedUsers->$FailKey) $Fails;
    
    :if ($Fails >= $MaxFailedAttempts) do={
      :set ($BlockedUsers->$UserKey) ({time=[:timestamp]});
      :set ($BlockedUsers->$FailKey) 0;
      :return true;
    }
    
    :return false;
  }

  # ============================================================================
  # MAIN BOT LOGIC
  # ============================================================================

  :if ([:len $TelegramTokenId] = 0 || $TelegramTokenId = "YOUR_BOT_TOKEN_HERE") do={
    :log error "TelegramTokenId not configured!";
    :set ExitOK true;
    :error false;
  }

  :if ([:typeof $TelegramChatOffset] != "array") do={
    :set TelegramChatOffset { 0; 0; 0 };
  }
  :if ([:typeof $TelegramRandomDelay] != "num") do={
    :set TelegramRandomDelay 0;
  }

  :if ([$CertificateAvailable "Go Daddy Root Certificate Authority - G2"] = false) do={
    :log warning ($ScriptName . " - Certificate download failed");
    :set ExitOK true;
    :error false;
  }

  # Random delay to prevent simultaneous polling
  :if ($TelegramRandomDelay > 0) do={
    :local RndDelay [:rndnum from=0 to=$TelegramRandomDelay];
    :delay ($RndDelay . "s");
  }

  # Fetch updates from Telegram
  :local Data false;
  :for I from=1 to=4 do={
    :if ($Data = false) do={
      :onerror FetchErr {
        :set Data ([ /tool/fetch check-certificate=no output=user \
          ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=" . \
          $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%5D") as-value ]->"data");
        :set TelegramRandomDelay ([:tonum $TelegramRandomDelay] - 1);
        :if ($TelegramRandomDelay < 0) do={ :set TelegramRandomDelay 0; }
      } do={
        :if ($I < 4) do={
          :log debug ($ScriptName . " - Fetch failed, " . $I . ". try: " . $FetchErr);
          :set TelegramRandomDelay ([:tonum $TelegramRandomDelay] + 5);
          :if ($TelegramRandomDelay > 15) do={ :set TelegramRandomDelay 15; }
          :delay (($I * $I) . "s");
        }
      }
    }
  }

  :if ($Data = false) do={
    :log warning ($ScriptName . " - Failed getting updates");
    :set ExitOK true;
    :error false;
  }

  # Process updates
  :local JSON [ :deserialize from=json value=$Data ];
  :local UpdateID 0;
  :local Uptime [ /system/resource/get uptime ];
  
  :foreach Update in=($JSON->"result") do={
    :set UpdateID ($Update->"update_id");
    :log debug ($ScriptName . " - Update " . $UpdateID);

    :local Message ($Update->"message");
    :local IsAnyReply ([:typeof ($Message->"reply_to_message")] = "array");
    :local IsMyReply ($TelegramMessageIDs->[:tostr ($Message->"reply_to_message"->"message_id")]);
    
    :if (($IsMyReply = 1 || $TelegramChatOffset->0 > 0 || $Uptime > 5m) && $UpdateID >= $TelegramChatOffset->2) do={
      :local Trusted false;
      :local Chat ($Message->"chat");
      :local From ($Message->"from");
      :local Command ($Message->"text");
      :local ThreadId "";
      :if (($Message->"is_topic_message") = true) do={
        :set ThreadId ($Message->"message_thread_id");
      }

      # Check if user is trusted
      :foreach IdsTrusted in=($TelegramChatId, $TelegramChatIdsTrusted) do={
        :if ($From->"id" = $IdsTrusted || \
             $From->"username" = $IdsTrusted || \
             $Chat->"id" = $IdsTrusted) do={
          :set Trusted true;
        }
      }

      :if ($Trusted = true) do={
        :local Done false;
        
        # Check if user is blocked
        :if ([$IsUserBlocked ($From->"id")] = true) do={
          :log warning ($ScriptName . " - Blocked user " . ($From->"id") . " attempted access");
          $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="🚫 Temporarily Blocked"; \
            message=("You are temporarily blocked due to too many failed attempts.\nPlease wait " . $BlockDuration . " minutes.") });
          :set Done true;
        }
        
        # Handle "?" - device query
        :if ($Done = false && $Command = "?") do={
          :log info ($ScriptName . " - Sending notice for update " . $UpdateID);
          :local ActiveStatus "";
          :if ($TelegramChatActive = true) do={ :set ActiveStatus " (and active!)"; }
          $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=true; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="🤖 Telegram Bot"; \
            message=("Hello " . ($From->"first_name") . "!\n\n" . \
              "Online" . $ActiveStatus . \
              ", awaiting your commands!") });
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
          :log info ($ScriptName . " - Now " . $StatusText . \
            " from update " . $UpdateID);
          :set Done true;
        }
        
        # Handle /help command
        :if ($Done = false && $Command = "/help") do={
          :local HelpText ("*Available Commands:*\n\n" . \
            "📱 *Bot Control:*\n" . \
            "`?` - Check bot status\n" . \
            "`! identity` - Activate device\n" . \
            "`! @all` - Activate all devices\n\n" . \
            "📊 *Information:*\n" . \
            "`/status` - System status\n" . \
            "`/interfaces` - Interface stats\n" . \
            "`/dhcp` - DHCP leases\n" . \
            "`/logs` - System logs\n" . \
            "`/wireless` - Wireless clients\n\n" . \
            "💾 *Management:*\n" . \
            "`/backup` - Create backup\n" . \
            "`/update` - Check updates\n\n" . \
            "⚡ *Advanced:*\n" . \
            "Activate device and send any RouterOS command\n\n" . \
            "🛡️ *Security:*\n" . \
            "• Rate limit: " . $CommandRateLimit . " cmds/min\n" . \
            "• Dangerous commands require confirmation\n" . \
            "• Use `CONFIRM code` to confirm");
          
          $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=true; \
            replyto=($Message->"message_id"); threadid=$ThreadId; \
            subject="📚 Bot Help"; message=$HelpText });
          :set Done true;
        }
        
        # Handle confirmation code (e.g., "CONFIRM ABC123")
        :if ($Done = false && $Command ~ "^CONFIRM [A-Z0-9]+\$") do={
          :local ConfirmCode [:pick $Command 8 [:len $Command]];
          :local ConfirmedCmd [$CheckConfirmation ($From->"id") $ConfirmCode];
          
          :if ([:len $ConfirmedCmd] > 0) do={
            :log info ($ScriptName . " - User " . ($From->"id") . " confirmed command: " . $ConfirmedCmd);
            # Set Command to the confirmed command and let it fall through to execution
            :set Command $ConfirmedCmd;
            :set TelegramChatActive true;
          } else={
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="❌ Invalid Confirmation"; \
              message="Invalid or expired confirmation code.\nPlease request the command again." });
            :set Done true;
          }
        }
        
        # Handle command execution
        :if ($Done = false && ($IsMyReply = 1 || ($IsAnyReply = false && \
             $TelegramChatActive = true)) && [:len $Command] > 0) do={
          
          # Check rate limit
          :if ([$CheckRateLimit ($From->"id")] = false) do={
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⏳ Rate Limited"; \
              message=("You are sending commands too fast.\nLimit: " . $CommandRateLimit . " commands per minute.\nPlease wait and try again.") });
            :set Done true;
          }
          
          :if ($Done = false) do={
          # Process custom command aliases
          :set Command [$ProcessCustomCommand $Command];
          
          # Check whitelist
          :if ([$CheckWhitelist $Command] = false) do={
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="🚫 Command Not Allowed"; \
              message=("This command is not in the whitelist.\n\nCommand: " . $Command) });
            :log warning ($ScriptName . " - User " . ($From->"id") . " tried non-whitelisted: " . $Command);
            :set Done true;
          }
          }
          
          # Check if command requires confirmation
          :if ($Done = false && [$RequiresConfirmation $Command] = true) do={
            :local ConfirmCode [$StorePendingConfirmation ($From->"id") $Command ($Message->"message_id")];
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚠️ Confirmation Required"; \
              message=("This command requires confirmation:\n\n" . \
                "Command: `" . $Command . "`\n\n" . \
                "⚠️ This is a potentially dangerous operation!\n\n" . \
                "To confirm, send:\n`CONFIRM " . $ConfirmCode . "`\n\n" . \
                "This code expires in 5 minutes.") });
            :log info ($ScriptName . " - Confirmation requested for: " . $Command);
            :set Done true;
          }
          
          :if ($Done = false) do={
          # Log command if enabled
          :if ($LogAllCommands = true) do={
            :log warning ($ScriptName . " - User " . ($From->"id") . " executed: " . $Command);
          }
          
          :if ([$ValidateSyntax $Command] = true) do={
            :local State "";
            :local TmpFile ("tmpfs/telegram-bot-" . $UpdateID);
            
            :log info ($ScriptName . " - Running command from update " . $UpdateID . ": " . $Command);
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
                :set State "⚠️ The command did not finish, still running in background.\n\n";
              } else={
                :delay 500ms;
              }
            }
            
            :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={
              :set State "❌ The command failed with an error!\n\n";
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
            
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=true; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚙️ Command Result"; \
              message=("⚙️ Command:\n" . $Command . "\n\n" . $State . $OutputText) });
            
            # Cleanup
            /file remove [find name~("^" . $TmpFile)];
          } else={
            :log info ($ScriptName . " - Command from update " . $UpdateID . " failed syntax validation");
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="⚙️ Command Error"; \
              message=("⚙️ Command:\n" . $Command . "\n\n" . \
                "❌ The command failed syntax validation!") });
          }
          }
        }
      } else={
        # Untrusted user
        :local UsernameText "";
        :if ([:len ($From->"username")] = 0) do={
          :set UsernameText "without username";
        } else={
          :set UsernameText ("'" . ($From->"username") . "'");
        }
        :local MessageText ("Received message from untrusted contact " . $UsernameText . \
          " (ID " . $From->"id" . ") in update " . $UpdateID);
        
        :if ($Command ~ ("^! *" . $Identity . "\$")) do={
          :log warning ($ScriptName . " - " . $MessageText);
          :if ($NotifyUntrustedAttempts = true) do={
            $SendTelegram2 ({ origin=$ScriptName; chatid=($Chat->"id"); silent=false; \
              replyto=($Message->"message_id"); threadid=$ThreadId; \
              subject="🚫 Access Denied"; \
              message="You are not trusted." });
          }
        } else={
          :log info ($ScriptName . " - " . $MessageText);
        }
      }
    } else={
      :log debug ($ScriptName . " - Already handled update " . $UpdateID);
    }
  }
  
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
