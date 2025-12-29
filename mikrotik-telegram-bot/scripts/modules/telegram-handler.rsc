#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram Handler Module
# Handles Telegram API polling, updates, callbacks, and inline queries
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, shared-functions, interactive-menu
#
# Exports:
#   - FetchBotUpdates: Get new updates from Telegram API
#   - ProcessUpdateQueue: Handle queue overflow
#   - HandleCallbackQueryEvent: Process inline button presses
#   - HandleInlineQueryEvent: Process inline search queries
#   - UpdateMessageOffset: Track processed messages
#   - InitializeOffsets: Set up offset tracking

# Loading guard
:do {
  :global TelegramHandlerLoaded
  :if ($TelegramHandlerLoaded) do={ :return }
} on-error={}

:local ScriptName "telegram-handler";

# Load dependencies
:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error ("[" . $ScriptName . "] - Failed to load shared-functions: " . $LoadErr);
    :return;
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/telegram-api";
  } do={
    :log error ("[" . $ScriptName . "] - Failed to load telegram-api: " . $LoadErr);
    :return;
  }
}

# Import required globals
:global TelegramTokenId;
:global TelegramChatId;
:global TelegramChatOffset;
:global TelegramMessageIDs;
:global FetchTelegramUpdates;
:global SendTelegram2;
:global IsUserTrusted;
:global AnswerCallbackQuery;
:global HandleCallbackQuery;
:global SearchScripts;
:global AnswerInlineQuery;
:global GetConnectedDevices;
:global Identity;

# ============================================================================
# INITIALIZE OFFSETS
# ============================================================================

:global InitializeOffsets do={
  :global TelegramChatOffset;
  :global TelegramMessageIDs;

  :if ([:typeof $TelegramChatOffset] != "array") do={
    :set TelegramChatOffset { 0; 0; 0 };
  }
  :if ([:typeof $TelegramMessageIDs] = "nothing") do={
    :set TelegramMessageIDs ({});
  }

  # Load persisted state
  :local StateFile "tmpfs/bot-state-runtime.txt";
  :onerror LoadErr {
    :if ([:len [/file find name=$StateFile]] > 0) do={
      :local StateData ([/file get $StateFile contents]);
      :if ([:len $StateData] > 0) do={
        :local StateJSON [:deserialize from=json $StateData];
        :if ([:typeof ($StateJSON->"offset")] = "array") do={
          :set TelegramChatOffset ($StateJSON->"offset");
        }
      }
    }
  } do={}

  :return ({
    "offset"=$TelegramChatOffset;
    "messageIds"=$TelegramMessageIDs
  });
}

# ============================================================================
# FETCH BOT UPDATES
# ============================================================================

:global FetchBotUpdates do={
  :global TelegramTokenId;
  :global TelegramChatOffset;
  :global FetchTelegramUpdates;

  :local JSON;

  # Try module function first
  :if ([:typeof $FetchTelegramUpdates] = "array") do={
    :set JSON [$FetchTelegramUpdates];
  } else={
    # Fallback direct fetch with retry
    :local Data false;
    :for I from=1 to=4 do={
      :if ($Data = false) do={
        :onerror FetchErr {
          :set Data ([/tool/fetch check-certificate=yes-without-crl output=user \
            ("https://api.telegram.org/bot" . $TelegramTokenId . "/getUpdates?offset=" . \
            $TelegramChatOffset->0 . "&allowed_updates=%5B%22message%22%2C%22callback_query%22%5D") as-value]->"data");
        } do={
          :if ($I < 4) do={ :delay (($I * $I) . "s"); }
        }
      }
    }
    :if ($Data != false) do={
      :set JSON [:deserialize from=json $Data];
    }
  }

  :if ([:typeof $JSON] = "nothing") do={
    :return ({
      "success"=false;
      "error"="Failed to fetch updates";
      "results"=({})
    });
  }

  :return ({
    "success"=true;
    "results"=($JSON->"result");
    "count"=[:len ($JSON->"result")]
  });
}

# ============================================================================
# PROCESS UPDATE QUEUE
# ============================================================================

:global ProcessUpdateQueue do={
  :local Results $1;
  :local QueueLen [:len $Results];

  :global TelegramChatOffset;
  :global SendTelegram2;

  :if ($QueueLen <= 3) do={
    :return ({
      "action"="process_all";
      "results"=$Results;
      "skipped"=0
    });
  }

  # Queue overflow - check for clear command
  :local LastIdx ($QueueLen - 1);
  :local LastUpdate ($Results->$LastIdx);
  :local LastMessage ($LastUpdate->"message");
  :local LastChat ($LastMessage->"chat");
  :local LastCommand ($LastMessage->"text");
  :local LastThreadId "";
  :if (($LastMessage->"is_topic_message") = true) do={
    :set LastThreadId ($LastMessage->"message_thread_id");
  }

  # Check if latest is clear command
  :if ($LastCommand = "/clear" || $LastCommand = "/clearqueue") do={
    :local LastUpdateID ($LastUpdate->"update_id");
    :set TelegramChatOffset ({ ($LastUpdateID + 1); ($LastUpdateID + 1); ($LastUpdateID + 1) });

    $SendTelegram2 ({
      chatid=($LastChat->"id");
      silent=false;
      replyto=($LastMessage->"message_id");
      threadid=$LastThreadId;
      subject="\E2\9A\A1 TxMTC | Queue Cleared";
      message=("\F0\9F\97\91 Cleared " . ($QueueLen - 1) . " pending messages.\nReady for new commands!")
    });

    :return ({
      "action"="cleared";
      "results"=({});
      "skipped"=($QueueLen - 1)
    });
  }

  # Not clear - notify and process only latest
  $SendTelegram2 ({
    chatid=($LastChat->"id");
    silent=true;
    threadid=$LastThreadId;
    subject="\E2\9A\A1 TxMTC | Queue Notice";
    message=("\F0\9F\93\AC " . $QueueLen . " pending messages in queue.\nProcessing latest only.\n\nSend `/clear` to empty queue.")
  });

  :return ({
    "action"="process_latest";
    "results"=({ $LastUpdate });
    "skipped"=($QueueLen - 1)
  });
}

# ============================================================================
# HANDLE CALLBACK QUERY EVENT
# ============================================================================

:global HandleCallbackQueryEvent do={
  :local CallbackQuery $1;

  :global TelegramChatId;
  :global SendTelegram2;
  :global IsUserTrusted;
  :global AnswerCallbackQuery;
  :global HandleCallbackQuery;
  :global GetConnectedDevices;
  :global Identity;

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

  # Check trust
  :local Trusted false;
  :if ([:typeof $IsUserTrusted] = "array") do={
    :set Trusted [$IsUserTrusted $CallbackFromId $CallbackChatId];
  } else={
    :if ($CallbackFromId = $TelegramChatId || $CallbackChatId = $TelegramChatId) do={
      :set Trusted true;
    }
  }

  :if ($Trusted != true) do={
    :return ({
      "processed"=true;
      "trusted"=false;
      "action"="ignored"
    });
  }

  # Handle command callbacks (cmd:command)
  :if ($CallbackData ~ "^cmd:") do={
    :local CmdToExecute [:pick $CallbackData 4 [:len $CallbackData]];

    :if ([:typeof $AnswerCallbackQuery] = "array") do={
      [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
    }

    :return ({
      "processed"=false;
      "trusted"=true;
      "action"="execute_command";
      "command"=$CmdToExecute;
      "chatId"=$CallbackChatId;
      "messageId"=[:tostr $CallbackMsgId];
      "threadId"=$ThreadId;
      "from"=$CallbackFrom
    });
  }

  # Handle monitoring callbacks
  :if ($CallbackData = "monitoring:refresh") do={
    :if ([:typeof $AnswerCallbackQuery] = "array") do={
      [$AnswerCallbackQuery [:tostr $CallbackId] "Refreshing monitoring..." false];
    }
    :onerror MonErr {
      /system script run "modules/monitoring";
    } do={}
    :return ({ "processed"=true; "trusted"=true; "action"="monitoring_refresh" });
  }

  :if ($CallbackData = "monitoring:devices") do={
    :if ([:typeof $AnswerCallbackQuery] = "array") do={
      [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
    }
    :if ([:typeof $GetConnectedDevices] = "array") do={
      :local DevicesMsg [$GetConnectedDevices];
      $SendTelegram2 ({ chatid=$CallbackChatId; silent=false; subject="📱 Connected Devices"; message=$DevicesMsg; threadid=$ThreadId });
    } else={
      $SendTelegram2 ({ chatid=$CallbackChatId; silent=false; subject="📱 Connected Devices"; message="Connected devices function not available."; threadid=$ThreadId });
    }
    :return ({ "processed"=true; "trusted"=true; "action"="monitoring_devices" });
  }

  :if ($CallbackData = "monitoring:command") do={
    :if ([:typeof $AnswerCallbackQuery] = "array") do={
      [$AnswerCallbackQuery [:tostr $CallbackId] "" false];
    }
    $SendTelegram2 ({
      chatid=$CallbackChatId;
      silent=false;
      subject="⚙️ RouterOS Command";
      message=("Type your RouterOS command now\\.\n\nExample:\n`/interface print`\n`/ip dhcp-server lease print`\n\nOr activate device first:\n`! " . $Identity . "`\n\nThen send your command\\.");
      threadid=$ThreadId
    });
    :return ({ "processed"=true; "trusted"=true; "action"="monitoring_command" });
  }

  # Delegate to interactive menu handler
  :if ([:typeof $HandleCallbackQuery] = "array") do={
    [$HandleCallbackQuery $CallbackData $CallbackChatId [:tostr $CallbackMsgId] $ThreadId [:tostr $CallbackId]];
    :return ({ "processed"=true; "trusted"=true; "action"="menu_callback" });
  }

  :return ({ "processed"=true; "trusted"=true; "action"="unknown" });
}

# ============================================================================
# HANDLE INLINE QUERY EVENT
# ============================================================================

:global HandleInlineQueryEvent do={
  :local InlineQuery $1;

  :global TelegramChatId;
  :global IsUserTrusted;
  :global SearchScripts;
  :global AnswerInlineQuery;

  :local QueryId ($InlineQuery->"id");
  :local QueryText ($InlineQuery->"query");
  :local QueryFrom ($InlineQuery->"from");
  :local QueryFromId [:tostr ($QueryFrom->"id")];

  # Check trust
  :local Trusted false;
  :if ([:typeof $IsUserTrusted] = "array") do={
    :set Trusted [$IsUserTrusted $QueryFromId $QueryFromId];
  } else={
    :if ($QueryFromId = $TelegramChatId) do={
      :set Trusted true;
    }
  }

  :if ($Trusted != true || [:len $QueryText] < 2) do={
    :return ({ "processed"=true; "trusted"=$Trusted; "results"=0 });
  }

  :if ([:typeof $SearchScripts] != "array" || [:typeof $AnswerInlineQuery] != "array") do={
    :return ({ "processed"=true; "trusted"=true; "results"=0; "error"="Functions not available" });
  }

  :local Results [$SearchScripts $QueryText];
  :local InlineResults ({});

  :foreach Script in=$Results do={
    :local ScriptId ($Script->"id");
    :local ScriptName ($Script->"name");
    :local ScriptDesc ($Script->"description");
    :if ([:len $ScriptDesc] > 100) do={
      :set ScriptDesc ([:pick $ScriptDesc 0 97] . "...");
    }

    :set ($InlineResults->[:len $InlineResults]) ({
      "type"="article";
      "id"=$ScriptId;
      "title"=$ScriptName;
      "description"=$ScriptDesc;
      "input_message_content"={
        "message_text"=("/install " . $ScriptId)
      }
    });

    # Limit to 10 results
    :if ([:len $InlineResults] >= 10) do={
      :set Script "";
    }
  }

  [$AnswerInlineQuery $QueryId $InlineResults];

  :return ({ "processed"=true; "trusted"=true; "results"=[:len $InlineResults] });
}

# ============================================================================
# UPDATE MESSAGE OFFSET
# ============================================================================

:global UpdateMessageOffset do={
  :local UpdateID $1;

  :global TelegramChatOffset;

  :local NewOffset;
  :if ($UpdateID >= $TelegramChatOffset->2) do={
    :set NewOffset ($UpdateID + 1);
  } else={
    :set NewOffset ($TelegramChatOffset->2);
  }
  :set TelegramChatOffset ([:pick $TelegramChatOffset 1 3], $NewOffset);

  :return $TelegramChatOffset;
}

# ============================================================================
# GET UPDATE TYPE
# ============================================================================

:global GetUpdateType do={
  :local Update $1;

  :if ([:typeof ($Update->"callback_query")] = "array") do={
    :return "callback";
  }
  :if ([:typeof ($Update->"inline_query")] = "array") do={
    :return "inline";
  }
  :if ([:typeof ($Update->"message")] = "array") do={
    :return "message";
  }
  :return "unknown";
}

# Mark as loaded
:global TelegramHandlerLoaded
:set TelegramHandlerLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
