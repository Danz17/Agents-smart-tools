#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Command Dispatcher Module
# Routes commands to appropriate handlers
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, security, execution-engine
#
# Exports:
#   - DispatchCommand: Main dispatcher function
#   - RegisterCommandHandler: Register new handlers
#   - GetCommandHandler: Lookup handler for command
#   - LoadCommandModules: Load all command modules

# Loading guard
:do {
  :global CommandDispatcherLoaded
  :if ($CommandDispatcherLoaded) do={ :return }
} on-error={}

:local ScriptName "command-dispatcher";

# Global command handler registry
:global CommandHandlers;
:if ([:typeof $CommandHandlers] != "array") do={
  :set CommandHandlers ({});
}

# Import required globals
:global TelegramChatActive;
:global Identity;
:global SendTelegram2;
:global SendBotReplyWithButtons;
:global CreateCommandButtons;
:global CreateInlineKeyboard;
:global SendTelegramWithKeyboard;

# ============================================================================
# REGISTER COMMAND HANDLER
# ============================================================================

:global RegisterCommandHandler do={
  :local CommandPattern [:tostr $1];
  :local Handler $2;
  :local Priority [:tonum $3];

  :global CommandHandlers;

  :if ([:typeof $Priority] != "num") do={
    :set Priority 100;
  }

  :set ($CommandHandlers->$CommandPattern) ({
    "handler"=$Handler;
    "priority"=$Priority;
    "pattern"=$CommandPattern
  });

  :log debug ("[command-dispatcher] - Registered handler for: " . $CommandPattern);
  :return true;
}

# ============================================================================
# GET COMMAND HANDLER
# ============================================================================

:global GetCommandHandler do={
  :local Command [:tostr $1];

  :global CommandHandlers;

  # Check exact match first
  :if ([:typeof ($CommandHandlers->$Command)] = "array") do={
    :return ($CommandHandlers->$Command);
  }

  # Check pattern matches
  :foreach Pattern,HandlerInfo in=$CommandHandlers do={
    :if ($Command ~ $Pattern) do={
      :return $HandlerInfo;
    }
  }

  :return ({});
}

# ============================================================================
# LOAD COMMAND MODULES
# ============================================================================

:global LoadCommandModules do={
  :global CoreCommandsLoaded;
  :global AdminCommandsLoaded;
  :global NetworkCommandsLoaded;

  # Load core commands
  :if ($CoreCommandsLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/commands-core";
    } do={
      :log warning ("[command-dispatcher] - Core commands not available");
    }
  }

  # Load admin commands
  :if ($AdminCommandsLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/commands-admin";
    } do={
      :log warning ("[command-dispatcher] - Admin commands not available");
    }
  }

  # Load network commands
  :if ($NetworkCommandsLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/commands-network";
    } do={
      :log warning ("[command-dispatcher] - Network commands not available");
    }
  }

  :return true;
}

# ============================================================================
# CHECK SECURITY REQUIREMENTS
# ============================================================================

:global CheckSecurityRequirements do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global IsDangerousCommand;
  :global CheckWhitelist;
  :global RequiresConfirmation;
  :global StorePendingConfirmation;
  :global SendTelegram2;

  :local ChatId ($MsgInfo->"chatId");
  :local MessageId ($MsgInfo->"messageId");
  :local ThreadId ($MsgInfo->"threadId");

  # Check dangerous commands blocklist
  :if ([:typeof $IsDangerousCommand] = "array") do={
    :if ([$IsDangerousCommand $Command] = true) do={
      $SendTelegram2 ({
        chatid=$ChatId;
        silent=false;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject="\E2\9A\A1 TxMTC | Blocked";
        message=("\E2\9B\94 Command blocked for security reasons:\n`" . $Command . "`")
      });
      :return ({
        "allowed"=false;
        "reason"="dangerous_command"
      });
    }
  }

  # Check whitelist
  :global WhitelistEnabled;
  :if ([:typeof $WhitelistEnabled] = "bool" && $WhitelistEnabled = true) do={
    :if ([:typeof $CheckWhitelist] = "array") do={
      :if ([$CheckWhitelist $Command] != true) do={
        $SendTelegram2 ({
          chatid=$ChatId;
          silent=false;
          replyto=$MessageId;
          threadid=$ThreadId;
          subject="\E2\9A\A1 TxMTC | Not Allowed";
          message=("\E2\9B\94 Command not in whitelist:\n`" . $Command . "`")
        });
        :return ({
          "allowed"=false;
          "reason"="not_whitelisted"
        });
      }
    }
  }

  # Check if confirmation required
  :if ([:typeof $RequiresConfirmation] = "array") do={
    :if ([$RequiresConfirmation $Command] = true) do={
      :local ConfirmCode [:rndnum from=1000 to=9999];
      :if ([:typeof $StorePendingConfirmation] = "array") do={
        [$StorePendingConfirmation $ChatId [:tostr $ConfirmCode] $Command];
      }

      $SendTelegram2 ({
        chatid=$ChatId;
        silent=false;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject="\E2\9A\A0\EF\B8\8F TxMTC | Confirm";
        message=("\E2\9A\A0\EF\B8\8F This command requires confirmation:\n`" . $Command . "`\n\nReply with:\n`CONFIRM " . $ConfirmCode . "`\n\nCode expires in 5 minutes.")
      });
      :return ({
        "allowed"=false;
        "reason"="confirmation_required";
        "confirmCode"=$ConfirmCode
      });
    }
  }

  :return ({
    "allowed"=true
  });
}

# ============================================================================
# PROCESS CONFIRMATION CODE
# ============================================================================

:global ProcessConfirmation do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global CheckConfirmation;
  :global SendTelegram2;

  :local ChatId ($MsgInfo->"chatId");
  :local MessageId ($MsgInfo->"messageId");
  :local ThreadId ($MsgInfo->"threadId");

  :if ($Command ~ "^CONFIRM ") do={
    :local ConfirmCode [:pick $Command 8 [:len $Command]];

    :if ([:typeof $CheckConfirmation] = "array") do={
      :local OriginalCmd [$CheckConfirmation $ChatId $ConfirmCode];
      :if ([:len $OriginalCmd] > 0) do={
        :return ({
          "valid"=true;
          "originalCommand"=$OriginalCmd
        });
      }
    }

    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Invalid";
      message="\E2\9D\8C Invalid or expired confirmation code."
    });
  }

  :return ({
    "valid"=false
  });
}

# ============================================================================
# DISPATCH COMMAND
# ============================================================================

:global DispatchCommand do={
  :local RouteResult $1;

  :global TelegramChatActive;
  :global Identity;
  :global CommandHandlers;
  :global GetCommandHandler;
  :global CheckSecurityRequirements;
  :global ProcessConfirmation;
  :global ExecuteCommandFull;
  :global LoadCommandModules;

  :local Command ($RouteResult->"command");
  :local MsgInfo ($RouteResult->"messageInfo");
  :local CommandType ($RouteResult->"commandType");
  :local TargetRouter ($RouteResult->"targetRouter");
  :local UpdateID ($RouteResult->"updateId");
  :local ShouldExecute ($RouteResult->"shouldExecute");

  # Ensure command modules are loaded
  [$LoadCommandModules];

  # Handle confirmation codes
  :if ($CommandType = "confirmation") do={
    :local ConfirmResult [$ProcessConfirmation $Command $MsgInfo];
    :if (($ConfirmResult->"valid") = true) do={
      :set Command ($ConfirmResult->"originalCommand");
      :set ShouldExecute true;
    } else={
      :return ({
        "handled"=true;
        "action"="confirmation_failed"
      });
    }
  }

  # Try to find a registered handler
  :local HandlerInfo [$GetCommandHandler $Command];
  :if ([:typeof ($HandlerInfo->"handler")] = "array") do={
    :local Handler ($HandlerInfo->"handler");
    :local Result [$Handler $Command $MsgInfo $RouteResult];
    :return ({
      "handled"=true;
      "action"="handler_executed";
      "result"=$Result
    });
  }

  # No handler - check if should execute as RouterOS command
  :if ($ShouldExecute != true) do={
    :return ({
      "handled"=false;
      "reason"="not_activated"
    });
  }

  # Security checks
  :local SecurityResult [$CheckSecurityRequirements $Command $MsgInfo];
  :if (($SecurityResult->"allowed") != true) do={
    :return ({
      "handled"=true;
      "action"="security_blocked";
      "reason"=($SecurityResult->"reason")
    });
  }

  # Execute as RouterOS command
  :local ExecResult [$ExecuteCommandFull $Command $MsgInfo $TargetRouter [:tostr $UpdateID]];

  :return ({
    "handled"=true;
    "action"="command_executed";
    "result"=$ExecResult
  });
}

# Mark as loaded
:global CommandDispatcherLoaded
:set CommandDispatcherLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
