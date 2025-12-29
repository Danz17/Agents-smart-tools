#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Smart Processor Module
# Natural language to RouterOS command translation via Claude AI
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: Alaa Qweider (Phenix)
# ═══════════════════════════════════════════════════════════════════════════
#
# Dependencies: claude-relay, claude-relay-native, github-ai-relay
#
# Exports:
#   - IsSmartCommandInput: Detect if input needs AI processing
#   - ProcessSmartInput: Main smart command handler
#   - TranslateToRouterOS: Convert natural language to command
#   - GetActiveRelayMode: Determine which relay to use

# Loading guard
:do {
  :global SmartProcessorLoaded
  :if ($SmartProcessorLoaded) do={ :return }
} on-error={}

:local ScriptName "smart-processor";

# Import required globals
:global ClaudeRelayEnabled;
:global ClaudeRelayNativeEnabled;
:global ClaudeRelayAutoExecute;
:global GitHubAIRelayEnabled;
:global ProcessSmartCommand;
:global ProcessSmartCommandNative;
:global ProcessSmartCommandGitHub;
:global ProcessCustomCommand;
:global SendTelegram2;

# ============================================================================
# GET ACTIVE RELAY MODE
# ============================================================================

:global GetActiveRelayMode do={
  :global ClaudeRelayEnabled;
  :global ClaudeRelayNativeEnabled;
  :global GitHubAIRelayEnabled;

  :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true) do={
    :return "native";
  }

  :if ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true) do={
    :return "python";
  }

  :if ([:typeof $GitHubAIRelayEnabled] = "bool" && $GitHubAIRelayEnabled = true) do={
    :return "github";
  }

  :return "none";
}

# ============================================================================
# CHECK IF SMART COMMAND INPUT
# ============================================================================

:global IsSmartCommandInput do={
  :local Command [:tostr $1];

  :global GetActiveRelayMode;

  # First check if any relay is enabled
  :local Mode [$GetActiveRelayMode];
  :if ($Mode = "none") do={
    :return false;
  }

  # Commands starting with / are not smart commands (unless they match patterns)
  :if ([:pick $Command 0 1] = "/") do={
    # Check for natural language patterns even with /
    :if ($Command ~ "^/(show|block|unblock|what|how|list|get|find|check|tell|give)") do={
      :return true;
    }
    :return false;
  }

  # Check for natural language patterns
  :local NaturalPatterns ({
    "^show ";
    "^list ";
    "^get ";
    "^find ";
    "^check ";
    "^what ";
    "^how ";
    "^why ";
    "^tell ";
    "^give ";
    "^block ";
    "^unblock ";
    "^enable ";
    "^disable ";
    "^restart ";
    "^reboot ";
    " active ";
    " users ";
    " interfaces ";
    " traffic ";
    " bandwidth ";
    " connected ";
    " status "
  });

  :local LowerCmd [:tostr $Command];
  # Simple lowercase conversion for common chars
  :foreach Pattern in=$NaturalPatterns do={
    :if ($Command ~ $Pattern) do={
      :return true;
    }
  }

  # If doesn't look like RouterOS command (no / or : at start)
  :if ([:pick $Command 0 1] != "/" && [:pick $Command 0 1] != ":") do={
    # Check if it's not a single word (likely natural language)
    :if ([:find $Command " "] != nil) do={
      :return true;
    }
  }

  :return false;
}

# ============================================================================
# PROCESS SMART INPUT
# ============================================================================

:global ProcessSmartInput do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global GetActiveRelayMode;
  :global ProcessSmartCommand;
  :global ProcessSmartCommandNative;
  :global ProcessSmartCommandGitHub;
  :global ClaudeRelayAutoExecute;
  :global SendTelegram2;

  :local ChatId ($MsgInfo->"chatId");
  :local ThreadId ($MsgInfo->"threadId");
  :local MessageId ($MsgInfo->"messageId");

  :local Mode [$GetActiveRelayMode];

  :if ($Mode = "none") do={
    :return ({
      "success"=false;
      "error"="No AI relay enabled";
      "shouldFallback"=true
    });
  }

  :local SmartResult ({success=false});

  # Try native mode first
  :if ($Mode = "native" && [:typeof $ProcessSmartCommandNative] = "array") do={
    :set SmartResult [$ProcessSmartCommandNative $Command];
  }

  # Then Python service
  :if (($SmartResult->"success") != true && $Mode = "python" && [:typeof $ProcessSmartCommand] = "array") do={
    :set SmartResult [$ProcessSmartCommand $Command];
  }

  # Finally GitHub Actions
  :if (($SmartResult->"success") != true && $Mode = "github" && [:typeof $ProcessSmartCommandGitHub] = "array") do={
    :set SmartResult [$ProcessSmartCommandGitHub $Command];
  }

  :if (($SmartResult->"success") = true) do={
    :local TranslatedCmd ($SmartResult->"routeros_command");
    :log info ("[smart-processor] - Translated: \"" . $Command . "\" -> \"" . $TranslatedCmd . "\"");

    # Show translation if auto-execute enabled
    :if ([:typeof $ClaudeRelayAutoExecute] = "bool" && $ClaudeRelayAutoExecute = true) do={
      $SendTelegram2 ({
        chatid=$ChatId;
        silent=true;
        replyto=$MessageId;
        threadid=$ThreadId;
        subject="\E2\9A\A1 TxMTC | Smart Command";
        message=("\F0\9F\A4\96 Translated:\n`" . $Command . "`\n\n\E2\86\92 `" . $TranslatedCmd . "`\n\nExecuting...")
      });
    }

    :return ({
      "success"=true;
      "originalCommand"=$Command;
      "routerosCommand"=$TranslatedCmd;
      "shouldExecute"=true
    });
  } else={
    :local ErrorMsg ($SmartResult->"error");
    :log warning ("[smart-processor] - Smart command failed: " . $ErrorMsg);

    $SendTelegram2 ({
      chatid=$ChatId;
      silent=false;
      replyto=$MessageId;
      threadid=$ThreadId;
      subject="\E2\9A\A1 TxMTC | Smart Command";
      message=("Could not process smart command:\n\n" . $Command . "\n\nError: " . $ErrorMsg . "\n\nTry using RouterOS command syntax instead.")
    });

    :return ({
      "success"=false;
      "error"=$ErrorMsg;
      "shouldFallback"=false
    });
  }
}

# ============================================================================
# PROCESS CUSTOM COMMAND ALIASES
# ============================================================================

:global ProcessCustomAlias do={
  :local Command [:tostr $1];

  :global ProcessCustomCommand;

  :if ([:typeof $ProcessCustomCommand] = "array") do={
    :return [$ProcessCustomCommand $Command];
  }

  :return $Command;
}

# ============================================================================
# FULL SMART PROCESSING PIPELINE
# ============================================================================

:global ProcessSmartPipeline do={
  :local Command [:tostr $1];
  :local MsgInfo $2;

  :global IsSmartCommandInput;
  :global ProcessSmartInput;
  :global ProcessCustomAlias;

  :local IsSmartCmd [$IsSmartCommandInput $Command];

  :if ($IsSmartCmd = true) do={
    :local SmartResult [$ProcessSmartInput $Command $MsgInfo];
    :if (($SmartResult->"success") = true) do={
      :return ({
        "processed"=true;
        "command"=($SmartResult->"routerosCommand");
        "originalCommand"=$Command;
        "wasSmartCommand"=true;
        "shouldExecute"=($SmartResult->"shouldExecute")
      });
    } else={
      # Smart processing failed - check if should fall back
      :if (($SmartResult->"shouldFallback") = true) do={
        # Fall back to custom alias processing
        :local ProcessedCmd [$ProcessCustomAlias $Command];
        :return ({
          "processed"=true;
          "command"=$ProcessedCmd;
          "originalCommand"=$Command;
          "wasSmartCommand"=false;
          "shouldExecute"=true
        });
      } else={
        # Smart processing failed definitively
        :return ({
          "processed"=true;
          "command"=$Command;
          "wasSmartCommand"=false;
          "shouldExecute"=false;
          "error"=($SmartResult->"error")
        });
      }
    }
  }

  # Not a smart command - process custom aliases
  :local ProcessedCmd [$ProcessCustomAlias $Command];
  :return ({
    "processed"=true;
    "command"=$ProcessedCmd;
    "originalCommand"=$Command;
    "wasSmartCommand"=false;
    "shouldExecute"=true
  });
}

# ============================================================================
# LOAD RELAY MODULES ON DEMAND
# ============================================================================

:global LoadRelayModules do={
  :global ClaudeRelayEnabled;
  :global ClaudeRelayNativeEnabled;
  :global GitHubAIRelayEnabled;

  # Load claude-relay-native if enabled
  :if ([:typeof $ClaudeRelayNativeEnabled] = "bool" && $ClaudeRelayNativeEnabled = true) do={
    :global ClaudeRelayNativeLoaded;
    :if ($ClaudeRelayNativeLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/claude-relay-native";
      } do={
        :log warning "[smart-processor] - Could not load claude-relay-native";
      }
    }
  }

  # Load claude-relay if enabled
  :if ([:typeof $ClaudeRelayEnabled] = "bool" && $ClaudeRelayEnabled = true) do={
    :global ClaudeRelayLoaded;
    :if ($ClaudeRelayLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/claude-relay";
      } do={
        :log warning "[smart-processor] - Could not load claude-relay";
      }
    }
  }

  # Load github-ai-relay if enabled
  :if ([:typeof $GitHubAIRelayEnabled] = "bool" && $GitHubAIRelayEnabled = true) do={
    :global GitHubAIRelayLoaded;
    :if ($GitHubAIRelayLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/github-ai-relay";
      } do={
        :log warning "[smart-processor] - Could not load github-ai-relay";
      }
    }
  }

  :return true;
}

# Mark as loaded
:global SmartProcessorLoaded
:set SmartProcessorLoaded true
:log info ("[" . $ScriptName . "] - Module loaded");
