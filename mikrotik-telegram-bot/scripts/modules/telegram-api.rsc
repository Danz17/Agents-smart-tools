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
  :local Text ("[" . $IdentStr . "] " . $Subject . "\n\n" . $Msg);
  
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
# CLEANUP OLD MESSAGES
# ============================================================================

:global CleanupOldMessages do={
  :local ChatId [ :tostr $1 ];
  :local RetentionPeriod $2;
  :local KeepCritical $3;
  
  :if ([:typeof $RetentionPeriod] != "time") do={
    :set RetentionPeriod 24h;
  }
  :if ([:typeof $KeepCritical] != "bool") do={
    :set KeepCritical true;
  }
  
  :global TelegramTokenId;
  :global TelegramMessageHistory;
  :local CurrentTime [:timestamp];
  :local Deleted 0;
  :local NewHistory ({});
  
  :foreach MsgId,MsgData in=$TelegramMessageHistory do={
    :local MsgChatId [:tostr ($MsgData->"chatid")];
    :if ($MsgChatId = $ChatId) do={
      :local MsgTime ($MsgData->"timestamp");
      :local Age ($CurrentTime - $MsgTime);
      :local IsCritical ($MsgData->"critical");
      
      :if ($Age > $RetentionPeriod && ($KeepCritical = false || $IsCritical = false)) do={
        # Delete message
        :onerror DelErr {
          :local DeleteUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/deleteMessage");
          :local DeleteData ("chat_id=" . $ChatId . "&message_id=" . $MsgId);
          :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
            /tool/fetch check-certificate=no output=none http-method=post $DeleteUrl http-data=$DeleteData;
          } else={
            /tool/fetch check-certificate=yes-without-crl output=none http-method=post $DeleteUrl http-data=$DeleteData;
          }
          :set Deleted ($Deleted + 1);
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
# INITIALIZATION FLAG
# ============================================================================

:global TelegramAPILoaded true;
:log info "Telegram API module loaded"
