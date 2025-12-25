#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# GitHub AI Relay Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Sends natural language commands to GitHub Actions for Claude AI processing
# Dependencies: shared-functions, telegram-api

# ============================================================================
# LOADING GUARD
# ============================================================================

:global GitHubAIRelayLoaded;
:if ($GitHubAIRelayLoaded = true) do={
  :return;
}

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error ("[github-ai-relay] - Failed to load shared-functions: " . $LoadErr);
    :return;
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global ParseJSON;
:global TelegramChatId;
:global Identity;

# ============================================================================
# CONFIGURATION
# ============================================================================

:global GitHubAIRelayEnabled;
:global GitHubRepoOwner;
:global GitHubRepoName;
:global GitHubToken;
:global GitHubBranch;
:global GitHubPollInterval;
:global GitHubPollTimeout;
:global GitHubAutoExecute;

:if ([:typeof $GitHubAIRelayEnabled] != "bool") do={ :set GitHubAIRelayEnabled false; }
:if ([:typeof $GitHubRepoOwner] != "str") do={ :set GitHubRepoOwner "Danz17"; }
:if ([:typeof $GitHubRepoName] != "str") do={ :set GitHubRepoName "Agents-smart-tools"; }
:if ([:typeof $GitHubToken] != "str") do={ :set GitHubToken ""; }
:if ([:typeof $GitHubBranch] != "str") do={ :set GitHubBranch "main"; }
:if ([:typeof $GitHubPollInterval] != "time") do={ :set GitHubPollInterval 5s; }
:if ([:typeof $GitHubPollTimeout] != "time") do={ :set GitHubPollTimeout 60s; }
:if ([:typeof $GitHubAutoExecute] != "bool") do={ :set GitHubAutoExecute false; }

# Pending command state
:global GitHubPendingCommandId;
:global GitHubPendingStartTime;

# ============================================================================
# GENERATE UNIQUE COMMAND ID
# ============================================================================

:global GenerateCommandId do={
  :local Timestamp [/system clock get time];
  :local Random [:pick ([/certificate scep-server otp generate minutes-valid=1 as-value]->"password") 0 8];
  :return ($Timestamp . "-" . $Random);
}

# ============================================================================
# GET RAW GITHUB FILE URL
# ============================================================================

:global GetGitHubRawURL do={
  :local FilePath [:tostr $1];
  :global GitHubRepoOwner;
  :global GitHubRepoName;
  :global GitHubBranch;

  :return ("https://raw.githubusercontent.com/" . $GitHubRepoOwner . "/" . $GitHubRepoName . "/" . $GitHubBranch . "/mikrotik-telegram-bot/" . $FilePath);
}

# ============================================================================
# PUSH COMMAND TO GITHUB
# ============================================================================

:global PushCommandToGitHub do={
  :local CommandText [:tostr $1];
  :local Context [:tostr $2];

  :global GitHubRepoOwner;
  :global GitHubRepoName;
  :global GitHubBranch;
  :global GitHubToken;
  :global Identity;
  :global GenerateCommandId;
  :global GitHubPendingCommandId;
  :global GitHubPendingStartTime;

  :if ([:len $GitHubToken] = 0) do={
    :return ({success=false; error="GitHub token not configured"});
  }

  # Generate command ID
  :local CmdId [$GenerateCommandId];
  :set GitHubPendingCommandId $CmdId;
  :set GitHubPendingStartTime [/system clock get time];

  # Build JSON payload
  :local JsonContent "{\"id\":\"";
  :set JsonContent ($JsonContent . $CmdId . "\",\"text\":\"");
  :set JsonContent ($JsonContent . $CommandText . "\",\"context\":\"");
  :set JsonContent ($JsonContent . "RouterOS 7.x on " . $Identity);
  :if ([:len $Context] > 0) do={
    :set JsonContent ($JsonContent . " - " . $Context);
  }
  :set JsonContent ($JsonContent . "\"}");

  # Get current file SHA (required for update)
  :local ApiUrl ("https://api.github.com/repos/" . $GitHubRepoOwner . "/" . $GitHubRepoName . "/contents/mikrotik-telegram-bot/commands/pending.json");

  :onerror Err {
    # Get current SHA
    :local GetResult [/tool fetch url=$ApiUrl mode=https \
      http-method=get \
      http-header-field=("Authorization: Bearer " . $GitHubToken . ",Accept: application/vnd.github.v3+json,User-Agent: TxMTC-Bot") \
      output=user as-value];

    :local CurrentData ($GetResult->"data");
    :local SHA "";

    # Extract SHA from response
    :local ShaPos [:find $CurrentData "\"sha\":\""];
    :if ([:typeof $ShaPos] = "num") do={
      :local ShaStart ($ShaPos + 7);
      :local ShaEnd [:find $CurrentData "\"" $ShaStart];
      :set SHA [:pick $CurrentData $ShaStart $ShaEnd];
    }

    # Encode content to base64
    :local Base64Content [:convert from=raw to=base64 $JsonContent];

    # Build update payload
    :local UpdatePayload "{\"message\":\"AI: Command from ";
    :set UpdatePayload ($UpdatePayload . $Identity . "\",\"content\":\"");
    :set UpdatePayload ($UpdatePayload . $Base64Content . "\",\"sha\":\"");
    :set UpdatePayload ($UpdatePayload . $SHA . "\",\"branch\":\"" . $GitHubBranch . "\"}");

    # Push to GitHub
    :local PutResult [/tool fetch url=$ApiUrl mode=https \
      http-method=put \
      http-header-field=("Authorization: Bearer " . $GitHubToken . ",Accept: application/vnd.github.v3+json,User-Agent: TxMTC-Bot,Content-Type: application/json") \
      http-data=$UpdatePayload \
      output=user as-value];

    :log info ("[github-ai-relay] - Pushed command: " . $CmdId);
    :return ({success=true; id=$CmdId});
  } do={
    :log error ("[github-ai-relay] - Failed to push: " . $Err);
    :return ({success=false; error=$Err});
  }
}

# ============================================================================
# FETCH RESPONSE FROM GITHUB
# ============================================================================

:global FetchResponseFromGitHub do={
  :global GetGitHubRawURL;
  :global ParseJSON;
  :global GitHubPendingCommandId;

  :local ResponseUrl [$GetGitHubRawURL "commands/response.json"];

  :onerror Err {
    :local Result [/tool fetch url=$ResponseUrl mode=https \
      http-method=get \
      output=user as-value];

    :local Data ($Result->"data");

    # Check if response is for our command
    :if ([:find $Data $GitHubPendingCommandId] != nil) do={
      # Parse response
      :local Response [$ParseJSON $Data];
      :return $Response;
    }

    :return ({status="waiting"});
  } do={
    :return ({status="error"; error=$Err});
  }
}

# ============================================================================
# POLL FOR RESPONSE
# ============================================================================

:global PollForAIResponse do={
  :global GitHubPollInterval;
  :global GitHubPollTimeout;
  :global GitHubPendingStartTime;
  :global FetchResponseFromGitHub;

  :local StartTime $GitHubPendingStartTime;
  :local MaxWait [:tonum $GitHubPollTimeout];
  :local Interval [:tonum $GitHubPollInterval];
  :local Elapsed 0;

  :while ($Elapsed < $MaxWait) do={
    :delay $Interval;
    :set Elapsed ($Elapsed + $Interval);

    :local Response [$FetchResponseFromGitHub];

    :if (($Response->"status") = "ready") do={
      :return $Response;
    }

    :if (($Response->"status") = "error") do={
      :return $Response;
    }
  }

  :return ({status="timeout"; error="No response within timeout"});
}

# ============================================================================
# PROCESS SMART COMMAND VIA GITHUB
# ============================================================================

:global ProcessSmartCommandGitHub do={
  :local CommandText [:tostr $1];

  :global PushCommandToGitHub;
  :global PollForAIResponse;
  :global GitHubAIRelayEnabled;

  :if ($GitHubAIRelayEnabled != true) do={
    :return ({success=false; error="GitHub AI relay not enabled"});
  }

  # Push command
  :local PushResult [$PushCommandToGitHub $CommandText ""];
  :if (($PushResult->"success") != true) do={
    :return $PushResult;
  }

  # Poll for response
  :local Response [$PollForAIResponse];

  :if (($Response->"status") = "ready") do={
    :local TranslatedCmd ($Response->"command");

    # Check for error response
    :if ($TranslatedCmd ~ "^ERROR:") do={
      :return ({
        success=false;
        error=[:pick $TranslatedCmd 7 [:len $TranslatedCmd]]
      });
    }

    # Check for confirmation required
    :if ($TranslatedCmd ~ "^CONFIRM:") do={
      :return ({
        success=true;
        routeros_command=[:pick $TranslatedCmd 9 [:len $TranslatedCmd]];
        requires_confirmation=true;
        original=$CommandText
      });
    }

    :return ({
      success=true;
      routeros_command=$TranslatedCmd;
      requires_confirmation=false;
      original=$CommandText
    });
  }

  :if (($Response->"status") = "timeout") do={
    :return ({success=false; error="AI response timed out"});
  }

  :return ({success=false; error=($Response->"error")});
}

# ============================================================================
# SHOW GITHUB AI STATUS
# ============================================================================

:global ShowGitHubAIStatus do={
  :global SendTelegram2;
  :global TelegramChatId;
  :global GitHubAIRelayEnabled;
  :global GitHubRepoOwner;
  :global GitHubRepoName;
  :global GitHubAutoExecute;

  :local Status "Disabled";
  :if ($GitHubAIRelayEnabled = true) do={
    :set Status "Enabled";
  }

  :local AutoExec "Off";
  :if ($GitHubAutoExecute = true) do={
    :set AutoExec "On";
  }

  :local Msg "*GitHub AI Relay Status*\n\n";
  :set Msg ($Msg . "Status: `" . $Status . "`\n");
  :set Msg ($Msg . "Repo: `" . $GitHubRepoOwner . "/" . $GitHubRepoName . "`\n");
  :set Msg ($Msg . "Auto-Execute: `" . $AutoExec . "`\n\n");
  :set Msg ($Msg . "_Send natural language commands like:_\n");
  :set Msg ($Msg . "`show connected hotspot users`\n");
  :set Msg ($Msg . "`block IP 192.168.1.50`\n");
  :set Msg ($Msg . "`list firewall rules`");

  :local Buttons ({});
  :if ($GitHubAIRelayEnabled = true) do={
    :set ($Buttons->[:len $Buttons]) ({{text="Disable"; callback_data="github-ai:disable"}});
  } else={
    :set ($Buttons->[:len $Buttons]) ({{text="Enable"; callback_data="github-ai:enable"}});
  }
  :set ($Buttons->[:len $Buttons]) ({{text="Back"; callback_data="menu:main"}});

  $SendTelegram2 ({
    chatid=$TelegramChatId;
    subject="GitHub AI Relay";
    message=$Msg;
    keyboard=$Buttons
  });
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:set GitHubAIRelayLoaded true;
:log info "GitHub AI Relay module loaded"
