#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Execution Engine Module
# Executes RouterOS commands locally or remotely with output handling
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: telegram-api, multi-router, shared-functions
#
# Exports:
#   - ExecuteCommand: Main execution function (auto-routes local/remote)
#   - ExecuteLocalCommand: Run command on this router
#   - ExecuteRemoteCommand: Route to remote router
#   - FormatCommandResult: Format output with buttons
#   - ValidateCommandSyntax: Check command syntax

# Loading guard
:do {
  :global ExecutionEngineLoaded
  :if ($ExecutionEngineLoaded) do={ :return }
} on-error={}

:local ScriptName "execution-engine";

# Load dependencies
:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log warning ("[" . $ScriptName . "] - Shared-functions not available");
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/telegram-api";
  } do={
    :log warning ("[" . $ScriptName . "] - Telegram-api not available");
  }
}

# Import required globals
:global TelegramChatRunTime;
:global SendTelegram2;
:global EditTelegramMessage;
:global CreateCommandButtons;
:global CreateInlineKeyboard;
:global SendTelegramWithKeyboard;
:global ValidateSyntax;
:global GetErrorSuggestions;
:global ClaudeRelayErrorSuggestions;
:global DetectMessageContext;
:global GetQuickActionsForContext;
:global TrackMessageContext;
:global SaveBotState;
:global LoadBotState;

# ============================================================================
# VALIDATE COMMAND SYNTAX
# ============================================================================

:global ValidateCommandSyntax do={
  :local Command [:tostr $1];

  :global ValidateSyntax;

  # Try module validator first
  :if ([:typeof $ValidateSyntax] = "array") do={
    :return [$ValidateSyntax $Command];
  }

  # Fallback to :parse
  :onerror SyntaxErr {
    :parse $Command;
    :return true;
  } do={
    :return false;
  }
}

# ============================================================================
# EXECUTE LOCAL COMMAND
# ============================================================================

:global ExecuteLocalCommand do={
  :local Command [:tostr $1];
  :local UpdateID [:tostr $2];

  :global TelegramChatRunTime;
  :global GetErrorSuggestions;
  :global ClaudeRelayErrorSuggestions;

  :local TmpFile ("tmpfs/telegram-bot-" . $UpdateID);

  :log info ("[execution-engine] - Executing: " . $Command);

  # Execute command
  :execute script=(":do {\n" . $Command . "\n} on-error={ /file/add name=\"" . $TmpFile . ".failed\" };" . \
    "/file/add name=\"" . $TmpFile . ".done\"") file=($TmpFile . "\00");

  # Wait for completion
  :local WaitTime [:totime $TelegramChatRunTime];
  :if ([:typeof $WaitTime] != "time") do={
    :set WaitTime 30s;
  }
  :local StartTime [/system clock get time];
  :local TimedOut false;
  :local State "";

  :while ([:len [/file find name=($TmpFile . ".done")]] = 0 && $TimedOut = false) do={
    :local CurrentTime [/system clock get time];
    :if (($CurrentTime - $StartTime) > $WaitTime) do={
      :set TimedOut true;
      :set State "\E2\9A\A0\EF\B8\8F Command still running in background.\n\n";
    } else={
      :delay 500ms;
    }
  }

  # Check for failure
  :local CommandFailed false;
  :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={
    :set State "\E2\9D\8C Command failed with an error!\n\n";
    :set CommandFailed true;
  }

  # Get output
  :local Content "";
  :if ([:len [/file find name=$TmpFile]] > 0) do={
    :set Content ([/file/get $TmpFile contents]);
  }

  :local OutputText "";
  :if ([:len $Content] > 0) do={
    :set OutputText ("\F0\9F\93\9D Output:\n" . $Content);
  } else={
    :set OutputText "\F0\9F\93\9D No output.";
  }

  # Get error suggestions if failed
  :local ErrorSuggestions "";
  :if ($CommandFailed = true && [:typeof $GetErrorSuggestions] = "array") do={
    :if ([:typeof $ClaudeRelayErrorSuggestions] = "bool" && $ClaudeRelayErrorSuggestions = true) do={
      :local SuggestionResult [$GetErrorSuggestions $Command $State $Content];
      :if (($SuggestionResult->"success") = true) do={
        :set ErrorSuggestions ($SuggestionResult->"suggestion");
        :set OutputText ($OutputText . "\n\n\F0\9F\92\A1 *Suggestion:*\n" . $ErrorSuggestions);
      }
    }
  }

  # Cleanup temp files
  :if ([:len [/file find name=$TmpFile]] > 0) do={ /file remove $TmpFile; }
  :if ([:len [/file find name=($TmpFile . ".done")]] > 0) do={ /file remove ($TmpFile . ".done"); }
  :if ([:len [/file find name=($TmpFile . ".failed")]] > 0) do={ /file remove ($TmpFile . ".failed"); }

  :return ({
    "success"=(!$CommandFailed);
    "timedOut"=$TimedOut;
    "state"=$State;
    "output"=$Content;
    "outputText"=$OutputText;
    "suggestion"=$ErrorSuggestions
  });
}

# ============================================================================
# EXECUTE REMOTE COMMAND
# ============================================================================

:global ExecuteRemoteCommandWrapper do={
  :local TargetRouter [:tostr $1];
  :local Command [:tostr $2];

  # Load multi-router module if needed
  :global MultiRouterLoaded;
  :if ($MultiRouterLoaded != true) do={
    :onerror LoadErr {
      /system script run "modules/multi-router";
    } do={
      :return ({
        "success"=false;
        "error"="Multi-router module not available"
      });
    }
  }

  :global ExecuteRemoteCommand;
  :if ([:typeof $ExecuteRemoteCommand] != "array") do={
    :return ({
      "success"=false;
      "error"="ExecuteRemoteCommand function not available"
    });
  }

  :log info ("[execution-engine] - Remote routing to: " . $TargetRouter);
  :local Result [$ExecuteRemoteCommand $TargetRouter $Command];

  :return $Result;
}

# ============================================================================
# FORMAT COMMAND RESULT
# ============================================================================

:global FormatCommandResult do={
  :local Command [:tostr $1];
  :local ExecResult $2;
  :local TargetRouter [:tostr $3];

  :global DetectMessageContext;
  :global GetQuickActionsForContext;
  :global CreateCommandButtons;

  :local State ($ExecResult->"state");
  :local OutputText ($ExecResult->"outputText");

  # Build result message
  :local ResultMsg "";
  :if ([:len $TargetRouter] > 0 && $TargetRouter != "local") do={
    :set ResultMsg ("*\F0\9F\96\A5\EF\B8\8F " . $TargetRouter . "* executed:\n`" . $Command . "`\n\n" . $State . $OutputText);
  } else={
    :set ResultMsg ("\E2\9A\99\EF\B8\8F Command:\n`" . $Command . "`\n\n" . $State . $OutputText);
  }

  # Detect context for quick actions
  :local MsgContext "command";
  :if ([:typeof $DetectMessageContext] = "array") do={
    :set MsgContext [$DetectMessageContext $Command $ResultMsg];
  }

  # Get quick action buttons
  :local QuickButtons ({});
  :if ([:typeof $GetQuickActionsForContext] = "array") do={
    :set QuickButtons [$GetQuickActionsForContext $MsgContext];
  }

  :return ({
    "message"=$ResultMsg;
    "context"=$MsgContext;
    "buttons"=$QuickButtons
  });
}

# ============================================================================
# EXECUTE COMMAND (Main Entry Point)
# ============================================================================

:global ExecuteCommandFull do={
  :local Command [:tostr $1];
  :local MsgInfo $2;
  :local TargetRouter [:tostr $3];
  :local UpdateID [:tostr $4];

  :global SendTelegram2;
  :global EditTelegramMessage;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;
  :global TrackMessageContext;
  :global SaveBotState;
  :global LoadBotState;
  :global TelegramMessageHistory;
  :global ValidateCommandSyntax;
  :global ExecuteLocalCommand;
  :global ExecuteRemoteCommandWrapper;
  :global FormatCommandResult;
  :global CreateCommandButtons;

  :local ChatId ($MsgInfo->"chatId");
  :local MessageId ($MsgInfo->"messageId");
  :local ThreadId ($MsgInfo->"threadId");

  # Validate syntax first
  :local SyntaxValid [$ValidateCommandSyntax $Command];
  :if ($SyntaxValid != true) do={
    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Error";
      message=("\E2\9A\99\EF\B8\8F Command:\n" . $Command . "\n\n\E2\9D\8C Syntax validation failed!")
    });
    :return ({
      "success"=false;
      "error"="Syntax validation failed"
    });
  }

  # Determine execution path
  :local LocalIdentity [/system identity get name];
  :local ExecuteRemote false;
  :if ([:len $TargetRouter] > 0 && $TargetRouter != "local" && $TargetRouter != $LocalIdentity) do={
    :set ExecuteRemote true;
  }

  # Execute command
  :local ExecResult;
  :if ($ExecuteRemote = true) do={
    :set ExecResult [$ExecuteRemoteCommandWrapper $TargetRouter $Command];
  } else={
    :set ExecResult [$ExecuteLocalCommand $Command $UpdateID];
    :set TargetRouter "local";
  }

  # Format result
  :local Formatted [$FormatCommandResult $Command $ExecResult $TargetRouter];
  :local ResultMsg ($Formatted->"message");
  :local MsgContext ($Formatted->"context");
  :local QuickButtons ($Formatted->"buttons");

  # Load message history
  :if ([:typeof $TelegramMessageHistory] != "array") do={
    :if ([:typeof $LoadBotState] = "array") do={
      :local LoadedHistory [$LoadBotState "message-history"];
      :if ([:typeof $LoadedHistory] = "array") do={
        :set TelegramMessageHistory $LoadedHistory;
      } else={
        :set TelegramMessageHistory ({});
      }
    } else={
      :set TelegramMessageHistory ({});
    }
  }

  :local CommandMsgKey ("cmd_" . $MessageId);
  :local ExistingMsgId ($TelegramMessageHistory->$CommandMsgKey);

  # Send result
  :local SentMsgId "";

  # For short outputs, try to edit existing message
  :if ([:len $ResultMsg] < 1000 && [:len $ExistingMsgId] > 0 && $ExistingMsgId != "0") do={
    :if ([:typeof $EditTelegramMessage] = "array") do={
      :local EditResult [$EditTelegramMessage $ChatId $ExistingMsgId $ResultMsg ""];
      :if ($EditResult = true) do={
        :set SentMsgId $ExistingMsgId;
      }
    }
  }

  # Send new message if edit failed or not applicable
  :if ([:len $SentMsgId] = 0) do={
    :local KeyboardJson "";
    :if ([:len $QuickButtons] > 0 && [:typeof $CreateInlineKeyboard] = "array") do={
      :set KeyboardJson [$CreateInlineKeyboard $QuickButtons];
    }

    :if ([:len $KeyboardJson] > 0 && [:typeof $SendTelegramWithKeyboard] = "array") do={
      :set SentMsgId [$SendTelegramWithKeyboard $ChatId $ResultMsg $KeyboardJson $ThreadId];
    } else={
      $SendTelegram2 ({
        chatid=$ChatId;
        silent=false;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject="\E2\9A\A1 TxMTC | Result";
        message=$ResultMsg
      });
    }
  }

  # Track message
  :if ([:len $SentMsgId] > 0) do={
    :set ($TelegramMessageHistory->$CommandMsgKey) $SentMsgId;
    :if ([:typeof $SaveBotState] = "array") do={
      [$SaveBotState "message-history" $TelegramMessageHistory];
    }

    # Track context for reply routing
    :if ([:typeof $TrackMessageContext] = "array") do={
      [$TrackMessageContext $SentMsgId $TargetRouter $MsgContext];
    }
  }

  :return ({
    "success"=($ExecResult->"success");
    "messageId"=$SentMsgId;
    "context"=$MsgContext
  });
}

# Mark as loaded
:global ExecutionEngineLoaded
:set ExecutionEngineLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
