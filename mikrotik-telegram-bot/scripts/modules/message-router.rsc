#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Message Router Module
# Routes incoming messages, validates trust, extracts reply context
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: security, telegram-api
#
# Exports:
#   - RouteMessage: Main routing function
#   - ValidateUserTrust: Check if user is authorized
#   - CheckUserBlocked: Check rate limit blocks
#   - ExtractReplyContext: Get router context from replies
#   - ExtractMessageInfo: Parse message metadata

# Loading guard
:do {
  :global MessageRouterLoaded
  :if ($MessageRouterLoaded) do={ :return }
} on-error={}

:local ScriptName "message-router";

# Load dependencies
:global SecurityModuleLoaded;
:if ($SecurityModuleLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/security";
  } do={
    :log warning ("[" . $ScriptName . "] - Security module not available");
  }
}

# Import required globals
:global TelegramChatId;
:global TelegramChatOffset;
:global TelegramMessageIDs;
:global TelegramChatActive;
:global Identity;
:global BlockDuration;
:global IsUserTrusted;
:global IsUserBlocked;
:global GetMessageContextByReply;
:global UpdateLastMessageTime;

# ============================================================================
# VALIDATE USER TRUST
# ============================================================================

:global ValidateUserTrust do={
  :local FromId [:tostr $1];
  :local ChatId [:tostr $2];

  :global TelegramChatId;
  :global IsUserTrusted;

  :if ([:typeof $IsUserTrusted] = "array") do={
    :return [$IsUserTrusted $FromId $ChatId];
  }

  # Fallback trust check
  :if ($FromId = $TelegramChatId || $ChatId = $TelegramChatId) do={
    :return true;
  }

  :return false;
}

# ============================================================================
# CHECK USER BLOCKED
# ============================================================================

:global CheckUserBlocked do={
  :local FromId [:tostr $1];

  :global IsUserBlocked;

  :if ([:typeof $IsUserBlocked] = "array") do={
    :return [$IsUserBlocked $FromId];
  }

  :return false;
}

# ============================================================================
# EXTRACT REPLY CONTEXT
# ============================================================================

:global ExtractReplyContext do={
  :local Message $1;

  :global TelegramMessageIDs;
  :global GetMessageContextByReply;

  :local Result ({
    "isReply"=false;
    "isMyReply"=false;
    "targetRouter"="";
    "replyMsgId"=""
  });

  :local IsAnyReply ([:typeof ($Message->"reply_to_message")] = "array");
  :if ($IsAnyReply != true) do={
    :return $Result;
  }

  :set ($Result->"isReply") true;
  :local ReplyMsgId [:tostr ($Message->"reply_to_message"->"message_id")];
  :set ($Result->"replyMsgId") $ReplyMsgId;

  # Check if reply is to our message
  :if ([:typeof ($TelegramMessageIDs->$ReplyMsgId)] != "nothing" && \
       ($TelegramMessageIDs->$ReplyMsgId) = 1) do={
    :set ($Result->"isMyReply") true;
  }

  # Check for router context (multi-router routing)
  :if ([:typeof $GetMessageContextByReply] = "array") do={
    :local RouterContext [$GetMessageContextByReply $ReplyMsgId];
    :if ([:typeof $RouterContext] = "array" && [:len ($RouterContext->"router")] > 0) do={
      :set ($Result->"targetRouter") ($RouterContext->"router");
      :set ($Result->"isMyReply") true;
    }
  }

  :return $Result;
}

# ============================================================================
# EXTRACT MESSAGE INFO
# ============================================================================

:global ExtractMessageInfo do={
  :local Message $1;

  :local Chat ($Message->"chat");
  :local From ($Message->"from");
  :local Command ($Message->"text");
  :local ThreadId "";

  :if (($Message->"is_topic_message") = true) do={
    :set ThreadId ($Message->"message_thread_id");
  }

  :return ({
    "chatId"=[:tostr ($Chat->"id")];
    "fromId"=[:tostr ($From->"id")];
    "username"=($From->"username");
    "firstName"=($From->"first_name");
    "command"=$Command;
    "messageId"=[:tostr ($Message->"message_id")];
    "threadId"=$ThreadId;
    "chat"=$Chat;
    "from"=$From
  });
}

# ============================================================================
# ROUTE MESSAGE
# ============================================================================

:global RouteMessage do={
  :local Update $1;

  :global TelegramChatOffset;
  :global TelegramChatActive;
  :global Identity;
  :global BlockDuration;
  :global SendTelegram2;
  :global UpdateLastMessageTime;
  :global ValidateUserTrust;
  :global CheckUserBlocked;
  :global ExtractReplyContext;
  :global ExtractMessageInfo;

  :local UpdateID ($Update->"update_id");
  :local Message ($Update->"message");

  # Check if we should process this update
  :if ($UpdateID < $TelegramChatOffset->2) do={
    :return ({
      "shouldProcess"=false;
      "reason"="old_update";
      "updateId"=$UpdateID
    });
  }

  :if ([:typeof $Message] != "array") do={
    :return ({
      "shouldProcess"=false;
      "reason"="no_message";
      "updateId"=$UpdateID
    });
  }

  # Extract message info
  :local MsgInfo [$ExtractMessageInfo $Message];
  :local FromId ($MsgInfo->"fromId");
  :local ChatId ($MsgInfo->"chatId");
  :local Command ($MsgInfo->"command");

  # Validate trust
  :local Trusted [$ValidateUserTrust $FromId $ChatId];

  :if ($Trusted != true) do={
    :return ({
      "shouldProcess"=false;
      "reason"="untrusted";
      "updateId"=$UpdateID;
      "fromId"=$FromId;
      "chatId"=$ChatId;
      "command"=$Command;
      "messageInfo"=$MsgInfo
    });
  }

  # Update activity timestamp
  :if ([:typeof $UpdateLastMessageTime] = "array") do={
    [$UpdateLastMessageTime];
  }

  # Check if user is blocked
  :if ([$CheckUserBlocked $FromId] = true) do={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=($MsgInfo->"messageId");
      threadid=($MsgInfo->"threadId");
      subject="\E2\9A\A1 TxMTC | Blocked";
      message=("Temporarily blocked - too many failed attempts.\nWait " . $BlockDuration . " min.")
    });
    :return ({
      "shouldProcess"=false;
      "reason"="blocked";
      "updateId"=$UpdateID
    });
  }

  # Extract reply context
  :local ReplyContext [$ExtractReplyContext $Message];

  # Determine if command should execute
  :local ShouldExecute false;
  :if ($TelegramChatActive = true) do={
    :set ShouldExecute true;
  }
  :if (($ReplyContext->"isMyReply") = true) do={
    :set ShouldExecute true;
  }

  # Classify command type
  :local CommandType "unknown";
  :if ($Command = "?") do={
    :set CommandType "status";
    :set ShouldExecute true;
  }
  :if ([:pick $Command 0 1] = "!") do={
    :set CommandType "activation";
    :set ShouldExecute true;
  }
  :if ($Command = "/help") do={
    :set CommandType "help";
    :set ShouldExecute true;
  }
  :if ($Command ~ "^/") do={
    :if ($CommandType = "unknown") do={
      :set CommandType "slash_command";
    }
  }
  :if ($Command ~ "^@") do={
    :set CommandType "remote_shorthand";
  }
  :if ($Command ~ "^CONFIRM ") do={
    :set CommandType "confirmation";
  }

  :return ({
    "shouldProcess"=true;
    "shouldExecute"=$ShouldExecute;
    "trusted"=true;
    "updateId"=$UpdateID;
    "commandType"=$CommandType;
    "command"=$Command;
    "messageInfo"=$MsgInfo;
    "replyContext"=$ReplyContext;
    "targetRouter"=($ReplyContext->"targetRouter")
  });
}

# ============================================================================
# HANDLE UNTRUSTED USER
# ============================================================================

:global HandleUntrustedUser do={
  :local MsgInfo $1;
  :local Command $2;

  :global Identity;
  :global NotifyUntrustedAttempts;
  :global SendTelegram2;

  :local FromId ($MsgInfo->"fromId");
  :local Username ($MsgInfo->"username");
  :local UsernameText "";

  :if ([:len $Username] = 0) do={
    :set UsernameText "without username";
  } else={
    :set UsernameText ("'" . $Username . "'");
  }

  :local MessageText ("Untrusted contact " . $UsernameText . " (ID " . $FromId . ")");

  # Check if activation attempt
  :if ($Command ~ ("^! *" . $Identity . "\$")) do={
    :log warning ("[message-router] - " . $MessageText . " attempted activation");
    :if ($NotifyUntrustedAttempts = true) do={
      $SendTelegram2 ({
        chatid=($MsgInfo->"chatId");
        silent=false;
        replyto=($MsgInfo->"messageId");
        threadid=($MsgInfo->"threadId");
        subject="\E2\9A\A1 TxMTC | Denied";
        message="Not trusted."
      });
    }
  } else={
    :log info ("[message-router] - " . $MessageText);
  }
}

# Mark as loaded
:global MessageRouterLoaded
:set MessageRouterLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
