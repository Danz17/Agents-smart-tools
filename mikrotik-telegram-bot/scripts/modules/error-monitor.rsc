#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Autonomous Error Monitor Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Autonomous error monitoring with Claude AI-powered analysis and fixing
# Dependencies: shared-functions, telegram-api, claude-relay-native

# ============================================================================
# LOADING GUARD
# ============================================================================

:global ErrorMonitorLoaded;
:if ($ErrorMonitorLoaded = true) do={
  :return;
}

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr in={
    /system script run "modules/shared-functions";
  } do={
    :log error "[error-monitor] - Failed to load shared-functions";
    :return;
  }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr in={
    /system script run "modules/telegram-api";
  } do={
    :log warning "[error-monitor] - telegram-api not available";
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global UrlEncode;
:global JsonEscape;

# ============================================================================
# CONFIGURATION
# ============================================================================

:global ErrorMonitorEnabled;
:if ([:typeof $ErrorMonitorEnabled] != "bool") do={
  :set ErrorMonitorEnabled false;
}

:global ErrorMonitorInterval;
:if ([:typeof $ErrorMonitorInterval] != "time") do={
  :set ErrorMonitorInterval 00:01:00;
}

:global ErrorMonitorAutoFix;
:if ([:typeof $ErrorMonitorAutoFix] != "bool") do={
  :set ErrorMonitorAutoFix false;
}

:global ErrorMonitorAdminChatId;
:if ([:typeof $ErrorMonitorAdminChatId] != "str") do={
  :set ErrorMonitorAdminChatId "";
}

:global ErrorMonitorMaxErrors;
:if ([:typeof $ErrorMonitorMaxErrors] != "num") do={
  :set ErrorMonitorMaxErrors 10;
}

:global ErrorMonitorCooldown;
:if ([:typeof $ErrorMonitorCooldown] != "time") do={
  :set ErrorMonitorCooldown 00:05:00;
}

# State tracking
:global ErrorMonitorLastCheck;
:if ([:typeof $ErrorMonitorLastCheck] != "time") do={
  :set ErrorMonitorLastCheck [:timestamp];
}

:global ErrorMonitorProcessedErrors;
:if ([:typeof $ErrorMonitorProcessedErrors] != "array") do={
  :set ErrorMonitorProcessedErrors ({});
}

:global ErrorMonitorFixHistory;
:if ([:typeof $ErrorMonitorFixHistory] != "array") do={
  :set ErrorMonitorFixHistory ({});
}

# ============================================================================
# SAFE COMMAND VALIDATION
# ============================================================================

:global IsSafeCommand do={
  :local Cmd [:tostr $1];

  # Dangerous command patterns - NEVER auto-execute
  :local Dangerous ({
    "/system reset";
    "/system reboot";
    "/system shutdown";
    "/file remove";
    "/system script remove";
    "/user remove";
    "/ip firewall filter remove";
    "/system package uninstall";
    "/interface bridge port remove";
    "/routing";
    "/certificate remove";
    "/ip ipsec";
    "/ppp secret remove";
  });

  :foreach Pattern in=$Dangerous do={
    :if ($Cmd ~ $Pattern) do={
      :log warning ("[error-monitor] Blocked dangerous: " . $Cmd);
      :return false;
    }
  }

  # Only allow specific safe operations
  :local SafePatterns ({
    "^/interface enable";
    "^/interface disable";
    "^/ip address set";
    "^/ip route set";
    "^/ip dns set";
    "^/system scheduler set";
    "^/system script set";
    "^/log print";
    "^/interface print";
    "^/ip address print";
  });

  :foreach Pattern in=$SafePatterns do={
    :if ($Cmd ~ $Pattern) do={
      :return true;
    }
  }

  # Default: not safe for auto-execution
  :return false;
}

# ============================================================================
# ERROR ANALYSIS WITH CLAUDE
# ============================================================================

:global AnalyzeErrorWithClaude do={
  :local ErrorMessage [:tostr $1];
  :local ErrorContext [:tostr $2];

  :global ClaudeRelayNativeEnabled;
  :global CallClaudeAPI;
  :global JsonEscape;

  # Check if Claude is available
  :if ($ClaudeRelayNativeEnabled != true) do={
    :return ({success=false; error="Claude not enabled"});
  }

  # Build analysis prompt
  :local Prompt ("RouterOS Error Analysis Request:\n\n" . \
    "Error: " . $ErrorMessage . "\n\n" . \
    "Context:\n" . \
    "- Device: " . [/system identity get value-name=name] . "\n" . \
    "- RouterOS: " . [/system resource get value-name=version] . "\n" . \
    "- Uptime: " . [/system resource get value-name=uptime] . "\n" . \
    "- CPU: " . [/system resource get value-name=cpu-load] . "%\n" . \
    "- RAM Free: " . [/system resource get value-name=free-memory] . "\n\n" . \
    "Additional Context: " . $ErrorContext . "\n\n" . \
    "Please analyze this error and respond in this exact format:\n" . \
    "CAUSE: <brief root cause>\n" . \
    "SEVERITY: <low|medium|high|critical>\n" . \
    "FIX: <RouterOS command if applicable, or 'manual' if requires human>\n" . \
    "PREVENTION: <brief prevention steps>\n\n" . \
    "If no fix command is applicable, set FIX: manual");

  :onerror AnalyzeErr in={
    :local Response [$CallClaudeAPI $Prompt];

    :if (($Response->"success") = true) do={
      :local Analysis ($Response->"routeros_command");

      # Parse response
      :local Cause "";
      :local Severity "medium";
      :local Fix "";
      :local Prevention "";

      # Extract CAUSE
      :if ($Analysis ~ "CAUSE:") do={
        :local CauseStart ([:find $Analysis "CAUSE:" -1] + 7);
        :local CauseEnd [:find $Analysis "\n" $CauseStart];
        :if ([:typeof $CauseEnd] = "num") do={
          :set Cause [:pick $Analysis $CauseStart $CauseEnd];
        }
      }

      # Extract SEVERITY
      :if ($Analysis ~ "SEVERITY:") do={
        :local SevStart ([:find $Analysis "SEVERITY:" -1] + 10);
        :local SevEnd [:find $Analysis "\n" $SevStart];
        :if ([:typeof $SevEnd] = "num") do={
          :set Severity [:pick $Analysis $SevStart $SevEnd];
          # Trim whitespace
          :set Severity [:pick $Severity 0 [:find $Severity " " -1]];
        }
      }

      # Extract FIX
      :if ($Analysis ~ "FIX:") do={
        :local FixStart ([:find $Analysis "FIX:" -1] + 5);
        :local FixEnd [:find $Analysis "\n" $FixStart];
        :if ([:typeof $FixEnd] = "num") do={
          :set Fix [:pick $Analysis $FixStart $FixEnd];
        } else={
          :set Fix [:pick $Analysis $FixStart [:len $Analysis]];
        }
      }

      # Extract PREVENTION
      :if ($Analysis ~ "PREVENTION:") do={
        :local PrevStart ([:find $Analysis "PREVENTION:" -1] + 12);
        :local PrevEnd [:find $Analysis "\n" $PrevStart];
        :if ([:typeof $PrevEnd] = "num") do={
          :set Prevention [:pick $Analysis $PrevStart $PrevEnd];
        } else={
          :set Prevention [:pick $Analysis $PrevStart [:len $Analysis]];
        }
      }

      :local HasFix false;
      :if ([:len $Fix] > 0 && $Fix != "manual" && $Fix != " manual") do={
        :set HasFix true;
      }

      :return ({
        success=true;
        cause=$Cause;
        severity=$Severity;
        fix=$Fix;
        has_fix=$HasFix;
        prevention=$Prevention;
        raw_analysis=$Analysis
      });
    }

    :return ({success=false; error=($Response->"error")});
  } do={
    :return ({success=false; error=$AnalyzeErr});
  }
}

# ============================================================================
# APPLY FIX
# ============================================================================

:global ApplyErrorFix do={
  :local Fix [:tostr $1];
  :local ErrorId [:tostr $2];

  :global IsSafeCommand;
  :global ErrorMonitorAutoFix;
  :global ErrorMonitorFixHistory;

  # Validate safety
  :if ([$IsSafeCommand $Fix] != true) do={
    :log warning ("[error-monitor] Fix blocked (unsafe): " . $Fix);
    :return ({success=false; error="Command not in safe list"; applied=false});
  }

  # Check if auto-fix is enabled
  :if ($ErrorMonitorAutoFix != true) do={
    :return ({success=false; error="Auto-fix disabled"; applied=false; command=$Fix});
  }

  # Execute the fix
  :onerror FixErr in={
    [[:parse $Fix]];
    :log info ("[error-monitor] Applied fix: " . $Fix);

    # Record in history
    :set ($ErrorMonitorFixHistory->$ErrorId) ({
      fix=$Fix;
      time=[:timestamp];
      success=true
    });

    :return ({success=true; applied=true; command=$Fix});
  } do={
    :log warning ("[error-monitor] Fix failed: " . $FixErr);

    :set ($ErrorMonitorFixHistory->$ErrorId) ({
      fix=$Fix;
      time=[:timestamp];
      success=false;
      error=$FixErr
    });

    :return ({success=false; error=$FixErr; applied=false; command=$Fix});
  }
}

# ============================================================================
# NOTIFY ADMIN
# ============================================================================

:global NotifyErrorAnalysis do={
  :local ErrorMsg [:tostr $1];
  :local Analysis $2;
  :local FixResult $3;

  :global SendTelegram2;
  :global ErrorMonitorAdminChatId;
  :global UrlEncode;

  :if ([:len $ErrorMonitorAdminChatId] = 0) do={
    :return;
  }

  # Build notification
  :local SeverityIcon "";
  :local Severity ($Analysis->"severity");
  :if ($Severity = "critical") do={ :set SeverityIcon "🔴"; }
  :if ($Severity = "high") do={ :set SeverityIcon "🟠"; }
  :if ($Severity = "medium") do={ :set SeverityIcon "🟡"; }
  :if ($Severity = "low") do={ :set SeverityIcon "🟢"; }

  :local Msg ($SeverityIcon . " *Error Detected*\n\n");
  :set Msg ($Msg . "*Error:* `" . $ErrorMsg . "`\n\n");
  :set Msg ($Msg . "*Cause:* " . ($Analysis->"cause") . "\n");
  :set Msg ($Msg . "*Severity:* " . $Severity . "\n\n");

  :if (($Analysis->"has_fix") = true) do={
    :set Msg ($Msg . "*Suggested Fix:*\n`" . ($Analysis->"fix") . "`\n\n");

    :if ([:typeof $FixResult] = "array") do={
      :if (($FixResult->"applied") = true) do={
        :set Msg ($Msg . "✅ *Auto-applied successfully*\n");
      } else={
        :if (($FixResult->"error") = "Auto-fix disabled") do={
          :set Msg ($Msg . "⏸️ Auto-fix disabled - manual action required\n");
        } else={
          :if (($FixResult->"error") = "Command not in safe list") do={
            :set Msg ($Msg . "⚠️ Command requires manual execution (safety)\n");
          } else={
            :set Msg ($Msg . "❌ Fix failed: " . ($FixResult->"error") . "\n");
          }
        }
      }
    }
  } else={
    :set Msg ($Msg . "ℹ️ *Manual intervention required*\n");
  }

  :set Msg ($Msg . "\n*Prevention:* " . ($Analysis->"prevention"));

  $SendTelegram2 ({
    chatid=$ErrorMonitorAdminChatId;
    subject="Error Analysis";
    message=$Msg
  });
}

# ============================================================================
# SCAN LOGS FOR ERRORS
# ============================================================================

:global ScanForErrors do={
  :global ErrorMonitorLastCheck;
  :global ErrorMonitorProcessedErrors;
  :global ErrorMonitorMaxErrors;

  :local Errors ({});
  :local Count 0;

  # Get recent error logs
  :onerror ScanErr in={
    :foreach LogId in=[/log find where topics~"error"] do={
      :if ($Count >= $ErrorMonitorMaxErrors) do={
        # Stop if max reached
      } else={
        :local LogTime [/log get $LogId value-name=time];
        :local LogMsg [/log get $LogId value-name=message];
        :local LogTopics [/log get $LogId value-name=topics];

        # Create unique error ID (use first 20 chars or whole message if shorter)
        :local MsgLen [:len $LogMsg];
        :local IdLen 20;
        :if ($MsgLen < 20) do={ :set IdLen $MsgLen; }
        :local ErrorId ([:tostr $LogTime] . "-" . [:pick $LogMsg 0 $IdLen]);

        # Skip if already processed
        :if ([:typeof ($ErrorMonitorProcessedErrors->$ErrorId)] = "nothing") do={
          :set ($Errors->$ErrorId) ({
            time=$LogTime;
            message=$LogMsg;
            topics=$LogTopics
          });
          :set ($ErrorMonitorProcessedErrors->$ErrorId) [:timestamp];
          :set Count ($Count + 1);
        }
      }
    }
  } do={
    :log warning ("[error-monitor] Scan failed: " . $ScanErr);
  }

  :set ErrorMonitorLastCheck [:timestamp];
  :return $Errors;
}

# ============================================================================
# MAIN ERROR MONITOR LOOP
# ============================================================================

:global RunErrorMonitor do={
  :global ErrorMonitorEnabled;
  :global ScanForErrors;
  :global AnalyzeErrorWithClaude;
  :global ApplyErrorFix;
  :global NotifyErrorAnalysis;
  :global ClaudeRelayNativeEnabled;

  :if ($ErrorMonitorEnabled != true) do={
    :log info "[error-monitor] Monitor disabled, skipping";
    :return;
  }

  :log info "[error-monitor] Starting error scan...";

  # Scan for new errors
  :local Errors [$ScanForErrors];
  :local ErrorCount [:len $Errors];

  :if ($ErrorCount = 0) do={
    :log info "[error-monitor] No new errors found";
    :return;
  }

  :log info ("[error-monitor] Found " . $ErrorCount . " new errors");

  # Process each error
  :foreach ErrorId,ErrorData in=$Errors do={
    :local ErrorMsg ($ErrorData->"message");
    :local ErrorTopics ($ErrorData->"topics");

    :log info ("[error-monitor] Analyzing: " . $ErrorMsg);

    # Skip if Claude not available
    :if ($ClaudeRelayNativeEnabled = true) do={
      # Get Claude analysis
      :local Analysis [$AnalyzeErrorWithClaude $ErrorMsg $ErrorTopics];

      :if (($Analysis->"success") = true) do={
        :local FixResult "";

        # Try to apply fix if available
        :if (($Analysis->"has_fix") = true) do={
          :set FixResult [$ApplyErrorFix ($Analysis->"fix") $ErrorId];
        }

        # Notify admin
        [$NotifyErrorAnalysis $ErrorMsg $Analysis $FixResult];

      } else={
        :log warning ("[error-monitor] Analysis failed: " . ($Analysis->"error"));
      }
    } else={
      :log warning "[error-monitor] Claude not available for analysis";
    }
  }

  :log info "[error-monitor] Error scan complete";
}

# ============================================================================
# SCHEDULER MANAGEMENT
# ============================================================================

:global StartErrorMonitor do={
  :global ErrorMonitorEnabled;
  :global ErrorMonitorInterval;

  :set ErrorMonitorEnabled true;

  # Remove existing scheduler if any
  :onerror RemoveErr in={
    /system scheduler remove [find name="TxMTC-ErrorMonitor"];
  } do={}

  # Create new scheduler
  /system scheduler add \
    name="TxMTC-ErrorMonitor" \
    interval=$ErrorMonitorInterval \
    on-event=":global RunErrorMonitor; [\$RunErrorMonitor]" \
    comment="TxMTC Autonomous Error Monitor";

  :log info ("[error-monitor] Started with interval: " . $ErrorMonitorInterval);
  :return ({success=true; message="Error monitor started"});
}

:global StopErrorMonitor do={
  :global ErrorMonitorEnabled;

  :set ErrorMonitorEnabled false;

  # Remove scheduler
  :onerror RemoveErr in={
    /system scheduler remove [find name="TxMTC-ErrorMonitor"];
  } do={}

  :log info "[error-monitor] Stopped";
  :return ({success=true; message="Error monitor stopped"});
}

:global GetErrorMonitorStatus do={
  :global ErrorMonitorEnabled;
  :global ErrorMonitorAutoFix;
  :global ErrorMonitorInterval;
  :global ErrorMonitorProcessedErrors;
  :global ErrorMonitorFixHistory;
  :global ClaudeRelayNativeEnabled;

  :local ProcessedCount [:len $ErrorMonitorProcessedErrors];
  :local FixCount [:len $ErrorMonitorFixHistory];

  :return ({
    enabled=$ErrorMonitorEnabled;
    auto_fix=$ErrorMonitorAutoFix;
    interval=$ErrorMonitorInterval;
    claude_available=$ClaudeRelayNativeEnabled;
    processed_errors=$ProcessedCount;
    applied_fixes=$FixCount
  });
}

# ============================================================================
# CLEANUP OLD PROCESSED ERRORS
# ============================================================================

:global CleanupProcessedErrors do={
  :global ErrorMonitorProcessedErrors;

  :local Now [:timestamp];
  :local MaxAge 86400; # 24 hours in seconds
  :local Cleaned 0;

  :local NewProcessed ({});
  :foreach ErrorId,ProcessedTime in=$ErrorMonitorProcessedErrors do={
    :local Age ($Now - $ProcessedTime);
    :if ($Age <= $MaxAge) do={
      :set ($NewProcessed->$ErrorId) $ProcessedTime;
    } else={
      :set Cleaned ($Cleaned + 1);
    }
  }
  :set ErrorMonitorProcessedErrors $NewProcessed;

  :if ($Cleaned > 0) do={
    :log info ("[error-monitor] Cleaned up " . $Cleaned . " old error records");
  }

  :return $Cleaned;
}

# ============================================================================
# INITIALIZATION
# ============================================================================

:set ErrorMonitorLoaded true;
:log info "[error-monitor] Module loaded successfully"
