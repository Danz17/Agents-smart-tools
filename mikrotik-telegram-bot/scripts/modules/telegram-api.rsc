#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Telegram API Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Telegram API communication functions
# Requires: shared-functions module loaded first

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :log warning "telegram-api - shared-functions not loaded, loading now...";
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error "telegram-api - Failed to load shared-functions module";
  }
}

# Import shared functions
:global UrlEncode;
:global CertificateAvailable;
:global SaveBotState;
:global LoadBotState;

# ============================================================================
# SEND TELEGRAM MESSAGE
# ============================================================================

:global SendTelegram2 do={
  :local Notification $1;
  
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global TelegramMessageIDs;
  :global TelegramQueue;
  :global Identity;
  :global IdentityExtra;
  :global UrlEncode;
  :global CertificateAvailable;
  
  # Get chat ID from notification or use default
  :local ChatId ($Notification->"chatid");
  :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
  
  # Get thread ID from notification or use default
  :local ThreadId ($Notification->"threadid");
  :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
  
  # Initialize message ID tracking
  :if ([:typeof $TelegramMessageIDs] = "nothing") do={
    :set TelegramMessageIDs ({});
  }
  
  # Initialize message history for cleanup
  :global TelegramMessageHistory;
  :if ([:typeof $TelegramMessageHistory] != "array") do={
    :local LoadedHistory [$LoadBotState "message-history"];
    :if ([:typeof $LoadedHistory] = "array") do={
      :set TelegramMessageHistory $LoadedHistory;
    } else={
      :set TelegramMessageHistory ({});
    }
  }
  
  # Build identity string
  :local IdentStr [:tostr $Identity];
  :if ([:typeof $IdentityExtra] = "str" && [:len $IdentityExtra] > 0) do={
    :set IdentStr ($IdentityExtra . $IdentStr);
  }
  
  # Build message text
  :local Subject [:tostr ($Notification->"subject")];
  :local Msg [:tostr ($Notification->"message")];
  :local Text "";
  :if ([:len $Subject] > 0) do={
    :set Text ("[" . $IdentStr . "] " . $Subject . "\n\n" . $Msg);
  } else={
    :set Text $Msg;
  }
  
  # Build HTTP data
  :local HTTPData ("chat_id=" . $ChatId . \
    "&disable_notification=" . ($Notification->"silent") . \
    "&reply_to_message_id=" . ($Notification->"replyto") . \
    "&message_thread_id=" . $ThreadId . \
    "&disable_web_page_preview=true");
  
  # Add inline keyboard if provided
  :if ([:typeof ($Notification->"keyboard")] = "str" && [:len ($Notification->"keyboard")] > 0) do={
    :set HTTPData ($HTTPData . "&reply_markup=" . [$UrlEncode ($Notification->"keyboard")]);
  }
  
  # Send message
  :onerror SendErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :log warning "telegram-api - Certificate not found, using check-certificate=no";
      :set Data ([ /tool/fetch check-certificate=no output=user http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]) as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]) as-value ]->"data");
    }
    # Store message ID for reply tracking
    :local MsgId [ :tostr ([ :deserialize from=json $Data ]->"result"->"message_id") ];
    :set ($TelegramMessageIDs->$MsgId) 1;
    
    # Track message for cleanup (check if critical flag is set)
    :local IsCritical false;
    :if ([:typeof ($Notification->"critical")] = "bool") do={
      :set IsCritical ($Notification->"critical");
    }
    :set ($TelegramMessageHistory->$MsgId) ({
      chatid=$ChatId;
      timestamp=[:timestamp];
      critical=$IsCritical;
      subject=$Subject
    });
    
    # Also track if this is a command message (for result editing)
    :local ReplyTo ($Notification->"replyto");
    :if ([:len $ReplyTo] > 0 && $ReplyTo != "0") do={
      :local CommandMsgKey ("cmd_" . [:tostr $ReplyTo]);
      :if ([:typeof ($TelegramMessageHistory->$CommandMsgKey)] = "nothing") do={
        :set ($TelegramMessageHistory->$CommandMsgKey) $MsgId;
      }
    }
    
    [$SaveBotState "message-history" $TelegramMessageHistory];
    
    :return $MsgId;
  } do={
    :log info ("telegram-api - Message queued: " . $SendErr);
    :if ([:typeof $TelegramQueue] = "nothing") do={
      :set TelegramQueue ({});
    }
    :set ($TelegramQueue->[:len $TelegramQueue]) { 
      tokenid=$TelegramTokenId;
      http-data=($HTTPData . "&text=" . [$UrlEncode $Text])
    };
    :return "";
  }
}

# ============================================================================
# SEND TELEGRAM MESSAGE (Simple Version)
# ============================================================================

:global SendTelegramSimple do={
  :local Subject [ :tostr $1 ];
  :local Message [ :tostr $2 ];
  :local Silent $3;
  
  :global SendTelegram2;
  
  :if ([:typeof $Silent] != "bool") do={
    :set Silent false;
  }
  
  $SendTelegram2 ({ 
    subject=$Subject; 
    message=$Message; 
    silent=$Silent 
  });
}

# ============================================================================
# GET TELEGRAM CHAT ID
# ============================================================================

:global GetTelegramChatId do={
  :global TelegramTokenId;
  :global CertificateAvailable;
  
  :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
    :log warning "GetTelegramChatId - Certificate ISRG Root X1 not found";
  }
  
  :local Data;
  :onerror FetchErr {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=0" . \
        "&allowed_updates=%5B%22message%22%5D") as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=0" . \
        "&allowed_updates=%5B%22message%22%5D") as-value ]->"data");
    }
  } do={
    :log warning ("GetTelegramChatId - Fetch failed: " . $FetchErr);
    :return;
  }
  
  :local JSON [ :deserialize from=json $Data ];
  :local Count [ :len ($JSON->"result") ];
  
  :if ($Count = 0) do={
    :log info "GetTelegramChatId - No messages received";
    :return;
  }
  
  :local Message ($JSON->"result"->($Count - 1)->"message");
  :local ChatId ($Message->"chat"->"id");
  :log info ("GetTelegramChatId - Chat ID: " . $ChatId);
  
  :if (($Message->"is_topic_message") = true) do={
    :local ThreadId ($Message->"message_thread_id");
    :log info ("GetTelegramChatId - Thread ID: " . $ThreadId);
    :return ({ chatid=$ChatId; threadid=$ThreadId });
  }
  
  :return ({ chatid=$ChatId });
}

# ============================================================================
# FETCH TELEGRAM UPDATES
# ============================================================================

:global FetchTelegramUpdates do={
  :global TelegramTokenId;
  :global TelegramChatOffset;
  :global TelegramRandomDelay;
  :global CertificateAvailable;
  
  :local Data false;
  :local MaxRetries 4;
  
  :for I from=1 to=$MaxRetries do={
    :if ($Data = false) do={
      :onerror FetchErr {
        :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
          :set Data ([ /tool/fetch check-certificate=no output=user \
            ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=" . \
            $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D") as-value ]->"data");
        } else={
          :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user \
            ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=" . \
            $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D") as-value ]->"data");
        }
        :set TelegramRandomDelay ([:tonum $TelegramRandomDelay] - 1);
        :if ($TelegramRandomDelay < 0) do={ :set TelegramRandomDelay 0; }
      } do={
        :if ($I < $MaxRetries) do={
          :log debug ("FetchTelegramUpdates - Retry " . $I . ": " . $FetchErr);
          :set TelegramRandomDelay ([:tonum $TelegramRandomDelay] + 5);
          :if ($TelegramRandomDelay > 15) do={ :set TelegramRandomDelay 15; }
          :delay (($I * $I) . "s");
        }
      }
    }
  }
  
  :if ($Data = false) do={
    :return;
  }
  
  :return [ :deserialize from=json $Data ];
}

# ============================================================================
# PROCESS TELEGRAM QUEUE
# ============================================================================

:global ProcessTelegramQueue do={
  :global TelegramQueue;
  :global CertificateAvailable;
  
  :if ([:typeof $TelegramQueue] != "array" || [:len $TelegramQueue] = 0) do={
    :return 0;
  }
  
  :local Processed 0;
  :local NewQueue ({});
  
  :foreach Item in=$TelegramQueue do={
    :onerror SendErr {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post \
          ("https://api.telegram.org/bot" . ($Item->"tokenid") . "/sendMessage") \
          http-data=($Item->"http-data");
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
          ("https://api.telegram.org/bot" . ($Item->"tokenid") . "/sendMessage") \
          http-data=($Item->"http-data");
      }
      :set Processed ($Processed + 1);
    } do={
      # Re-queue failed messages
      :set ($NewQueue->[:len $NewQueue]) $Item;
    }
  }
  
  :set TelegramQueue $NewQueue;
  :return $Processed;
}

# ============================================================================
# MESSAGE TRACKING AND CLEANUP
# ============================================================================

# Initialize message history
:global TelegramMessageHistory;
:if ([:typeof $TelegramMessageHistory] != "array") do={
  :local LoadedHistory [$LoadBotState "message-history"];
  :if ([:typeof $LoadedHistory] = "array") do={
    :set TelegramMessageHistory $LoadedHistory;
  } else={
    :set TelegramMessageHistory ({});
  }
}

# Clean up old command message IDs on startup (older than 24 hours)
:local CurrentTime [:timestamp];
:local CleanedHistory ({});
:local MonitoringMsgId ($TelegramMessageHistory->"monitoring_msg_id");
:if ([:len $MonitoringMsgId] > 0) do={
  :set ($CleanedHistory->"monitoring_msg_id") $MonitoringMsgId;
}
:foreach MsgId,MsgData in=$TelegramMessageHistory do={
  :if ($MsgId != "monitoring_msg_id" && $MsgId ~ "^cmd_") do={
    # Keep command message IDs (they're cleaned up when commands complete)
    :set ($CleanedHistory->$MsgId) ($TelegramMessageHistory->$MsgId);
  } else={
    :if ($MsgId != "monitoring_msg_id") do={
      # Keep regular message history
      :set ($CleanedHistory->$MsgId) $MsgData;
    }
  }
}
:set TelegramMessageHistory $CleanedHistory;

# ============================================================================
# MARK MESSAGE AS CRITICAL
# ============================================================================

:global MarkMessageCritical do={
  :local MsgId [ :tostr $1 ];
  
  :if ([:typeof ($TelegramMessageHistory->$MsgId)] = "array") do={
    :set ($TelegramMessageHistory->$MsgId->"critical") true;
    [$SaveBotState "message-history" $TelegramMessageHistory];
    :return true;
  }
  :return false;
}

# ============================================================================
# GET MESSAGE AGE
# ============================================================================

:global GetMessageAge do={
  :local MsgId [ :tostr $1 ];
  
  :if ([:typeof ($TelegramMessageHistory->$MsgId)] = "array") do={
    :local MsgTime ($TelegramMessageHistory->$MsgId->"timestamp");
    :local CurrentTime [:timestamp];
    :return ($CurrentTime - $MsgTime);
  }
  :return;
}

# ============================================================================
# CLEANUP OLD MESSAGES (Enhanced - more aggressive cleanup)
# ============================================================================

:global CleanupOldMessages do={
  :local ChatId [ :tostr $1 ];
  :local RetentionPeriod $2;
  :local KeepCritical $3;
  
  :if ([:typeof $RetentionPeriod] != "time") do={
    :set RetentionPeriod 6h;
  }
  :if ([:typeof $KeepCritical] != "bool") do={
    :set KeepCritical true;
  }
  
  :global TelegramTokenId;
  :global TelegramMessageHistory;
  :global DeleteTelegramMessage;
  :local CurrentTime [:timestamp];
  :local Deleted 0;
  :local NewHistory ({});
  :local IrrelevantSubjects ({"Queue Notice"; "Interface Recovered"; "CPU Utilization Recovered"; "RAM Utilization Recovered"; "Disk Usage Recovered"});
  
  :foreach MsgId,MsgData in=$TelegramMessageHistory do={
    :local MsgChatId [:tostr ($MsgData->"chatid")];
    :if ($MsgChatId = $ChatId) do={
      :local MsgTime ($MsgData->"timestamp");
      :local Age ($CurrentTime - $MsgTime);
      :local IsCritical ($MsgData->"critical");
      :local Subject [:tostr ($MsgData->"subject")];
      :local ShouldDelete false;
      
      # Delete if older than retention period (unless critical)
      :if ($Age > $RetentionPeriod && ($KeepCritical = false || $IsCritical = false)) do={
        :set ShouldDelete true;
      }
      
      # Delete irrelevant recovery/status messages after 1 hour (even if recent)
      :if ($Age > 1h && $IsCritical = false) do={
        :foreach IrrelevantSubj in=$IrrelevantSubjects do={
          :if ($Subject ~ $IrrelevantSubj) do={
            :set ShouldDelete true;
          }
        }
      }
      
      :if ($ShouldDelete = true) do={
        # Delete message
        :onerror DelErr {
          :local DelResult [$DeleteTelegramMessage $ChatId $MsgId];
          :if ($DelResult = true) do={
            :set Deleted ($Deleted + 1);
          } else={
            # Keep in history if deletion failed
            :set ($NewHistory->$MsgId) $MsgData;
          }
        } do={
          # Keep in history if deletion failed
          :set ($NewHistory->$MsgId) $MsgData;
        }
      } else={
        # Keep message
        :set ($NewHistory->$MsgId) $MsgData;
      }
    } else={
      # Keep messages from other chats
      :set ($NewHistory->$MsgId) $MsgData;
    }
  }
  
  :set TelegramMessageHistory $NewHistory;
  [$SaveBotState "message-history" $TelegramMessageHistory];
  :log debug ("telegram-api - Cleaned up " . $Deleted . " old messages for chat " . $ChatId);
  :return $Deleted;
}

# ============================================================================
# AUTO CLEANUP (called periodically)
# ============================================================================

:global AutoCleanupMessages do={
  :global MessageRetentionPeriod;
  :global KeepCriticalMessages;
  :global AutoCleanupEnabled;
  :global TelegramChatId;
  
  :if ([:typeof $AutoCleanupEnabled] != "bool" || $AutoCleanupEnabled = false) do={
    :return 0;
  }
  
  :if ([:typeof $MessageRetentionPeriod] != "time") do={
    :set MessageRetentionPeriod 24h;
  }
  :if ([:typeof $KeepCriticalMessages] != "bool") do={
    :set KeepCriticalMessages true;
  }
  
  :return [$CleanupOldMessages $TelegramChatId $MessageRetentionPeriod $KeepCriticalMessages];
}

# ============================================================================
# EDIT TELEGRAM MESSAGE
# ============================================================================

:global EditTelegramMessage do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];
  :local Text [ :tostr $3 ];
  :local KeyboardJSON [ :tostr $4 ];

  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;

  :if ([:len $MessageId] = 0 || $MessageId = "0") do={
    :return false;
  }

  :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
  :local HTTPData ("chat_id=" . $ChatId . \
    "&message_id=" . $MessageId . \
    "&text=" . [$UrlEncode $Text] . \
    "&parse_mode=MarkdownV2");

  :if ([:len $KeyboardJSON] > 0) do={
    :set HTTPData ($HTTPData . "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
  }

  :onerror EditErr {
    :local ResponseData "";
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      :set ResponseData ([ /tool/fetch check-certificate=no output=user http-method=post $EditUrl http-data=$HTTPData as-value ]->"data");
    } else={
      :set ResponseData ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post $EditUrl http-data=$HTTPData as-value ]->"data");
    }
    
    # Check if edit was successful
    :if ([:len $ResponseData] > 0) do={
      :local ResponseJSON [:deserialize from=json $ResponseData];
      :if (($ResponseJSON->"ok") = true) do={
        :return true;
      }
      # Check for "message not found" or "message can't be edited" errors
      :local ErrorCode ($ResponseJSON->"error_code");
      :if ([:typeof $ErrorCode] = "num") do={
        :if ($ErrorCode = 400 || $ErrorCode = 404) do={
          :log debug ("telegram-api - Message deleted or can't be edited: " . $MessageId);
          :return false;
        }
      }
    }
    :return false;
  } do={
    :log warning ("telegram-api - EditTelegramMessage failed: " . $EditErr);
    :return false;
  }
}

# ============================================================================
# ANSWER CALLBACK QUERY
# ============================================================================

:global AnswerCallbackQuery do={
  :local CallbackId [ :tostr $1 ];
  :local Text [ :tostr $2 ];
  :local ShowAlert $3;

  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;

  :if ([:typeof $ShowAlert] != "bool") do={
    :set ShowAlert false;
  }

  :local AnswerUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/answerCallbackQuery");
  :local HTTPData ("callback_query_id=" . $CallbackId);

  :if ([:len $Text] > 0) do={
    :set HTTPData ($HTTPData . "&text=" . [$UrlEncode $Text]);
  }
  :if ($ShowAlert = true) do={
    :set HTTPData ($HTTPData . "&show_alert=true");
  }

  :onerror AnswerErr {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no output=none http-method=post $AnswerUrl http-data=$HTTPData;
    } else={
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post $AnswerUrl http-data=$HTTPData;
    }
    :return true;
  } do={
    :return false;
  }
}

# ============================================================================
# DELETE TELEGRAM MESSAGE
# ============================================================================

:global DeleteTelegramMessage do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];

  :global TelegramTokenId;
  :global CertificateAvailable;

  :if ([:len $MessageId] = 0 || $MessageId = "0") do={
    :return false;
  }

  :local DeleteUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/deleteMessage");
  :local HTTPData ("chat_id=" . $ChatId . "&message_id=" . $MessageId);

  :onerror DelErr {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no output=none http-method=post $DeleteUrl http-data=$HTTPData;
    } else={
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post $DeleteUrl http-data=$HTTPData;
    }
    :return true;
  } do={
    :log debug ("telegram-api - DeleteTelegramMessage failed: " . $DelErr);
    :return false;
  }
}

# ============================================================================
# SEND OR UPDATE MESSAGE (Smart - edits if message ID provided)
# ============================================================================

:global SendOrUpdateMessage do={
  :local ChatId [ :tostr $1 ];
  :local Text [ :tostr $2 ];
  :local ExistingMsgId [ :tostr $3 ];
  :local KeyboardJSON [ :tostr $4 ];

  :global EditTelegramMessage;
  :global SendTelegram2;
  :global SaveBotState;
  :global LoadBotState;

  # If we have an existing message ID, try to edit it
  :if ([:len $ExistingMsgId] > 0 && $ExistingMsgId != "0") do={
    :local EditResult [$EditTelegramMessage $ChatId $ExistingMsgId $Text $KeyboardJSON];
    :if ($EditResult = true) do={
      :return $ExistingMsgId;
    }
    # Message was deleted or edit failed, fall through to send new message
  }

  # Otherwise send new message
  :local NewMsgId [$SendTelegram2 ({ chatid=$ChatId; subject=""; message=$Text; silent=true })];
  :return $NewMsgId;
}

# ============================================================================
# GET OR CREATE MONITORING MESSAGE (Single shared message for all alerts)
# ============================================================================

:global GetOrCreateMonitoringMessage do={
  :local ChatId [ :tostr $1 ];
  :local MessageText [ :tostr $2 ];
  :local KeyboardJSON [ :tostr $3 ];
  
  :global TelegramMessageHistory;
  :global SendTelegram2;
  :global SendTelegramWithKeyboard;
  :global EditTelegramMessage;
  :global SaveBotState;
  :global LoadBotState;
  :global CreateInlineKeyboard;
  
  # Ensure message history is loaded
  :if ([:typeof $TelegramMessageHistory] != "array") do={
    :local LoadedHistory [$LoadBotState "message-history"];
    :if ([:typeof $LoadedHistory] = "array") do={
      :set TelegramMessageHistory $LoadedHistory;
    } else={
      :set TelegramMessageHistory ({});
    }
  }
  
  :local MonitoringKey "monitoring_msg_id";
  :local MonitoringMsgId "";
  :if ([:typeof ($TelegramMessageHistory->$MonitoringKey)] = "str") do={
    :set MonitoringMsgId ($TelegramMessageHistory->$MonitoringKey);
  }
  
  # Try to edit existing message
  :if ([:len $MonitoringMsgId] > 0 && $MonitoringMsgId != "0") do={
    :local EditResult [$EditTelegramMessage $ChatId $MonitoringMsgId $MessageText $KeyboardJSON];
    :if ($EditResult = true) do={
      :log debug ("telegram-api - Monitoring message edited: " . $MonitoringMsgId);
      :return $MonitoringMsgId;
    }
    # Message was deleted, clear ID
    :log debug ("telegram-api - Monitoring message deleted, creating new one");
    :set ($TelegramMessageHistory->$MonitoringKey) "";
  }
  
  # Create new message
  :local NewMsgId "";
  :if ([:len $KeyboardJSON] > 0 && [:typeof $SendTelegramWithKeyboard] = "array") do={
    :set NewMsgId [$SendTelegramWithKeyboard $ChatId $MessageText $KeyboardJSON ""];
  } else={
    :set NewMsgId [$SendTelegram2 ({ chatid=$ChatId; subject=""; message=$MessageText; silent=true })];
  }
  
  :if ([:len $NewMsgId] > 0) do={
    :set ($TelegramMessageHistory->$MonitoringKey) $NewMsgId;
    [$SaveBotState "message-history" $TelegramMessageHistory];
    :log debug ("telegram-api - New monitoring message created: " . $NewMsgId);
  }
  :return $NewMsgId;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global TelegramAPILoaded true;
:log info "Telegram API module loaded"
