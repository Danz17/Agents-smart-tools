#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Claude Code Relay Module (Native RouterOS - Direct API)
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Native RouterOS implementation - Directly calls Claude API
# No Python service required!
# Dependencies: shared-functions

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :log warning "claude-relay-native - shared-functions not loaded, loading now...";
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error "claude-relay-native - Failed to load shared-functions module";
  }
}

# Import shared functions
:global UrlEncode;
:global CertificateAvailable;
:global JsonEscape;

# ============================================================================
# CONFIGURATION (set in bot-config.rsc)
# ============================================================================

:global ClaudeAPIKey;
:if ([:typeof $ClaudeAPIKey] != "str" || [:len $ClaudeAPIKey] < 10) do={
  :set ClaudeAPIKey "";
}

:global ClaudeAPIModel;
:if ([:typeof $ClaudeAPIModel] != "str" || [:len $ClaudeAPIModel] = 0) do={
  :set ClaudeAPIModel "claude-3-5-sonnet-20241022";
}

:global ClaudeAPITimeout;
:if ([:typeof $ClaudeAPITimeout] != "time") do={
  :set ClaudeAPITimeout 30s;
}

:global ClaudeRelayNativeEnabled;
:if ([:typeof $ClaudeRelayNativeEnabled] != "bool") do={
  :set ClaudeRelayNativeEnabled false;
}

# ============================================================================
# BUILD SYSTEM PROMPT
# ============================================================================

:global BuildClaudeSystemPrompt do={
  :local Prompt ("You are a RouterOS command expert assistant. Your task is to translate natural language commands or high-level abstractions into valid RouterOS commands.\n\n" . \
    "RouterOS Command Syntax:\n" . \
    "- Commands start with \"/\" (e.g., /interface print)\n" . \
    "- Use \"where\" clause for filtering (e.g., /interface print where status!=\"up\")\n" . \
    "- Use \"find\" for searching (e.g., /ip firewall filter find where src-address=\"192.168.1.0/24\")\n" . \
    "- Use \"add\" to create (e.g., /ip firewall filter add chain=forward action=drop)\n" . \
    "- Use \"remove\" or \"set\" to modify\n\n" . \
    "Common Operations:\n" . \
    "- show interfaces: /interface print stats\n" . \
    "- show errors: /interface print where status!=\"up\"\n" . \
    "- block device: /ip firewall filter add chain=forward src-address={ip} action=drop\n" . \
    "- show dhcp: /ip dhcp-server lease print\n" . \
    "- show firewall: /ip firewall filter print\n\n" . \
    "Safety Rules:\n" . \
    "- NEVER generate dangerous commands like /system reset-configuration\n" . \
    "- Always validate command syntax before returning\n" . \
    "- Prefer read-only commands when intent is unclear\n\n" . \
    "Instructions:\n" . \
    "1. Analyze the user's request\n" . \
    "2. Determine the appropriate RouterOS command\n" . \
    "3. Return ONLY the RouterOS command, nothing else\n" . \
    "4. If the request is ambiguous, return a safe read-only command\n" . \
    "5. If the request cannot be fulfilled, return an error message starting with \"ERROR:\"\n\n" . \
    "Return format: Just the RouterOS command, or \"ERROR: <reason>\" if not possible.");
  :return $Prompt;
}

# ============================================================================
# CALL CLAUDE API DIRECTLY
# ============================================================================

:global CallClaudeAPI do={
  :local UserMessage [ :tostr $1 ];
  :global ClaudeAPIKey;
  :global ClaudeAPIModel;
  :global ClaudeAPITimeout;
  :global CertificateAvailable;
  :global UrlEncode;
  :global BuildClaudeSystemPrompt;
  
  # Check if API key is configured
  :if ([:len $ClaudeAPIKey] < 10) do={
    :return ({success=false; error="Claude API key not configured"});
  }
  
  # Build system prompt
  :local SystemPrompt [$BuildClaudeSystemPrompt];
  
  # Build JSON payload
  # Note: RouterOS JSON serialization is limited, so we build manually
  # Use JsonEscape function for proper escaping
  :local EscapedPrompt "";
  :if ([:typeof $JsonEscape] = "array") do={
    :set EscapedPrompt [$JsonEscape $SystemPrompt];
  } else={
    # Fallback if JsonEscape not available
    :set EscapedPrompt $SystemPrompt;
    :set EscapedPrompt [:replace $EscapedPrompt from="\\" to="\\\\"];
    :set EscapedPrompt [:replace $EscapedPrompt from="\"" to="\\\""];
    :set EscapedPrompt [:replace $EscapedPrompt from="\n" to="\\n"];
  }
  
  :local EscapedMessage "";
  :if ([:typeof $JsonEscape] = "array") do={
    :set EscapedMessage [$JsonEscape $UserMessage];
  } else={
    # Fallback if JsonEscape not available
    :set EscapedMessage $UserMessage;
    :set EscapedMessage [:replace $EscapedMessage from="\\" to="\\\\"];
    :set EscapedMessage [:replace $EscapedMessage from="\"" to="\\\""];
    :set EscapedMessage [:replace $EscapedMessage from="\n" to="\\n"];
  }
  
  :local Payload ("{\"model\":\"" . $ClaudeAPIModel . "\"," . \
    "\"max_tokens\":1024," . \
    "\"system\":\"" . $EscapedPrompt . "\"," . \
    "\"messages\":[{\"role\":\"user\",\"content\":\"" . $EscapedMessage . "\"}]}");
  
  :local APIURL "https://api.anthropic.com/v1/messages";
  :local TimeoutNum [:totime $ClaudeAPITimeout];
  
  # RouterOS fetch supports http-header-field but only one header at a time
  # We need to use http-header-field multiple times or combine headers
  # Actually, RouterOS 7.x supports multiple http-header-field entries
  :onerror APIErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user http-method=post timeout=$TimeoutNum \
        http-header-field=("x-api-key: " . $ClaudeAPIKey) \
        http-header-field="anthropic-version: 2023-06-01" \
        http-header-field="Content-Type: application/json" \
        http-data=$Payload \
        $APIURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post timeout=$TimeoutNum \
        http-header-field=("x-api-key: " . $ClaudeAPIKey) \
        http-header-field="anthropic-version: 2023-06-01" \
        http-header-field="Content-Type: application/json" \
        http-data=$Payload \
        $APIURL as-value ]->"data");
    }
    
    :if ([:len $Data] > 0) do={
      :local Response [ :deserialize from=json $Data ];
      
      # Check for errors
      :if ([:typeof ($Response->"error")] = "array") do={
        :local ErrorMsg ($Response->"error"->"message");
        :return ({success=false; error=$ErrorMsg});
      }
      
      # Extract content
      :if ([:typeof ($Response->"content")] = "array" && [:len ($Response->"content")] > 0) do={
        :local FirstContent ($Response->"content"->0);
        :if ([:typeof ($FirstContent->"text")] = "str") do={
          :local CommandText ($FirstContent->"text");
          :return ({success=true; routeros_command=$CommandText; original_command=$UserMessage});
        }
      }
      
      :return ({success=false; error="Unexpected API response format"});
    }
    :return ({success=false; error="Empty response from Claude API"});
  } do={
    :return ({success=false; error=$APIErr});
  }
}

# ============================================================================
# PROCESS SMART COMMAND (NATIVE)
# ============================================================================

:global ProcessSmartCommandNative do={
  :local Command [ :tostr $1 ];
  :global ClaudeRelayNativeEnabled;
  :global CallClaudeAPI;
  
  # Check if native mode is enabled
  :if ($ClaudeRelayNativeEnabled != true) do={
    :return ({success=false; error="Native Claude relay not enabled"; original_command=$Command});
  }
  
  # Call Claude API directly
  :local Response [$CallClaudeAPI $Command];
  
  # Check if processing was successful
  :if (($Response->"success") = true) do={
    :local RouterOSCommand ($Response->"routeros_command");
    # Clean up command (remove quotes, whitespace)
    :while ([:pick $RouterOSCommand 0 1] = " " || [:pick $RouterOSCommand 0 1] = "\"") do={
      :set RouterOSCommand [:pick $RouterOSCommand 1 [:len $RouterOSCommand]];
    }
    :while ([:pick $RouterOSCommand ([:len $RouterOSCommand] - 1) [:len $RouterOSCommand]] = " " || \
            [:pick $RouterOSCommand ([:len $RouterOSCommand] - 1) [:len $RouterOSCommand]] = "\"") do={
      :set RouterOSCommand [:pick $RouterOSCommand 0 ([:len $RouterOSCommand] - 1)];
    }
    
    :log info ("claude-relay-native - Processed: \"" . $Command . "\" -> \"" . $RouterOSCommand . "\"");
    :return ({success=true; routeros_command=$RouterOSCommand; original_command=$Command});
  } else={
    :local ErrorMsg ($Response->"error");
    :log warning ("claude-relay-native - Failed: " . $ErrorMsg);
    :return ({success=false; error=$ErrorMsg; original_command=$Command});
  }
}

# ============================================================================
# VALIDATE ROUTEROS COMMAND
# ============================================================================

:global ValidateRouterOSCommand do={
  :local Command [ :tostr $1 ];
  
  :if ([:len $Command] = 0) do={
    :return ({valid=false; error="Empty command"});
  }
  
  # Check for dangerous commands
  :local Dangerous ({"/system reset-configuration"; "/system package uninstall"; "/system reboot"; "/system shutdown"});
  :foreach DangerousCmd in=$Dangerous do={
    :if ($Command ~ ("^" . $DangerousCmd)) do={
      :return ({valid=false; error=("Dangerous command blocked: " . $DangerousCmd)});
    }
  }
  
  # Basic syntax validation
  :if ([:pick $Command 0 1] != "/") do={
    :return ({valid=false; error="RouterOS commands must start with '/'"});
  }
  
  :return ({valid=true; command=$Command});
}

# ============================================================================
# MODULE LOADED FLAG
# ============================================================================

:global ClaudeRelayNativeLoaded true;
:log info "claude-relay-native - Native module loaded (direct Claude API)";


