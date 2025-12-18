#!rsc by RouterOS
# MikroTik Telegram Bot - Shared Functions Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Shared helper functions used across all modules
# Import this module to use: /import modules/shared-functions.rsc

# ============================================================================
# URL ENCODING
# ============================================================================

# URL encode - improved UTF-8 handling
:global UrlEncode do={
  :local String [ :tostr $1 ];
  :local Result "";
  :for I from=0 to=([:len $String] - 1) do={
    :local Char [:pick $String $I ($I + 1)];
    :if ($Char ~ "[A-Za-z0-9_.~-]") do={
      :set Result ($Result . $Char);
    } else={
      :if ($Char = " ") do={
        :set Result ($Result . "%20");
      } else={
        :if ($Char = "\n") do={
          :set Result ($Result . "%0A");
        } else={
          :if ($Char = "\r") do={
            :set Result ($Result . "%0D");
          } else={
            :if ($Char = "\t") do={
              :set Result ($Result . "%09");
            } else={
              # Encode special characters
              :local CharArray [:toarray $Char];
              :local FirstChar ($CharArray->0);
              :local CharCode [:tonum $FirstChar];
              :if ([:typeof $CharCode] = "num" && $CharCode >= 0 && $CharCode <= 255) do={
                :local Hex1 [:pick "0123456789ABCDEF" ($CharCode / 16) ($CharCode / 16 + 1)];
                :local Hex2 [:pick "0123456789ABCDEF" ($CharCode % 16) ($CharCode % 16 + 1)];
                :set Result ($Result . ("%" . $Hex1 . $Hex2));
              } else={
                # Fallback for multi-byte characters (encode as-is, Telegram handles it)
                :set Result ($Result . $Char);
              }
            }
          }
        }
      }
    }
  }
  :return $Result;
}

# ============================================================================
# FORMAT BYTES
# ============================================================================

# Format bytes to human readable
:global FormatBytes do={
  :local Bytes [:tonum $1];
  :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
  :local UnitIndex 0;
  
  :while ($Bytes >= 1024 && $UnitIndex < 4) do={
    :set Bytes ($Bytes / 1024);
    :set UnitIndex ($UnitIndex + 1);
  }
  
  :return ([:tostr $Bytes] . ($Units->$UnitIndex));
}

# ============================================================================
# SEND TELEGRAM MESSAGE
# ============================================================================

# Send Telegram message (standardized across modules)
:global SendTelegram2 do={
  :local Notification $1;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global Identity;
  :global UrlEncode;
  
  :local ChatId ([$1 "chatid"]);
  :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
  
  :local ThreadId ([$1 "threadid"]);
  :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
  
  :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . \
    ($Notification->"message"));
  
  :local HTTPData ("chat_id=" . $ChatId . \
    "&disable_notification=" . ($Notification->"silent") . \
    "&message_thread_id=" . $ThreadId . \
    "&parse_mode=Markdown");
  
  :onerror SendErr {
    /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
      ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
      http-data=($HTTPData . "&text=" . [$UrlEncode $Text]);
  } do={
    :log warning ("shared-functions - Failed to send notification: " . $SendErr);
  }
}

# ============================================================================
# STATE PERSISTENCE
# ============================================================================

# Save state to file
:global SaveState do={
  :local StateName [ :tostr $1 ];
  :local StateData [ :tostr $2 ];
  :local StateFile ("tmpfs/bot-state-" . $StateName . ".txt");
  
  :onerror SaveErr {
    /file/print file=$StateFile to=$StateData;
    :log debug ("shared-functions - Saved state: " . $StateName);
  } do={
    :log warning ("shared-functions - Failed to save state " . $StateName . ": " . $SaveErr);
  }
}

# Load state from file
:global LoadState do={
  :local StateName [ :tostr $1 ];
  :local StateFile ("tmpfs/bot-state-" . $StateName . ".txt");
  :local StateData "";
  
  :onerror LoadErr {
    :if ([:len [/file find name=$StateFile]] > 0) do={
      :set StateData ([/file get $StateFile contents]);
      :log debug ("shared-functions - Loaded state: " . $StateName);
    }
  } do={
    :log debug ("shared-functions - State file not found: " . $StateName);
  }
  
  :return $StateData;
}

:log info "Shared functions module loaded"
