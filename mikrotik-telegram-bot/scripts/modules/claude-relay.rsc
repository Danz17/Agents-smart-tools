#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Claude Code Relay Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Smart command processing using Claude Code Relay Node
# Dependencies: shared-functions

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :log warning "claude-relay - shared-functions not loaded, loading now...";
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error "claude-relay - Failed to load shared-functions module";
  }
}

# Import shared functions
:global UrlEncode;
:global CertificateAvailable;

# ============================================================================
# CONFIGURATION (set in bot-config.rsc)
# ============================================================================

:global ClaudeRelayEnabled;
:if ([:typeof $ClaudeRelayEnabled] != "bool") do={
  :set ClaudeRelayEnabled false;
}

:global ClaudeRelayURL;
:if ([:typeof $ClaudeRelayURL] != "str" || [:len $ClaudeRelayURL] = 0) do={
  :set ClaudeRelayURL "http://192.168.1.100:5000";
}

:global ClaudeRelayTimeout;
:if ([:typeof $ClaudeRelayTimeout] != "time") do={
  :set ClaudeRelayTimeout 10s;
}

:global ClaudeRelayMode;
:if ([:typeof $ClaudeRelayMode] != "str" || [:len $ClaudeRelayMode] = 0) do={
  :set ClaudeRelayMode "anthropic";
}

# ============================================================================
# CHECK SERVICE AVAILABILITY
# ============================================================================

:global ClaudeRelayAvailable do={
  :global ClaudeRelayURL;
  :global ClaudeRelayTimeout;
  :global CertificateAvailable;
  
  :local HealthURL ($ClaudeRelayURL . "/health");
  :local TimeoutNum [:totime $ClaudeRelayTimeout];
  
  :onerror HealthErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user timeout=$TimeoutNum \
        $HealthURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user timeout=$TimeoutNum \
        $HealthURL as-value ]->"data");
    }
    
    :if ([:len $Data] > 0) do={
      :local Response [ :deserialize from=json $Data ];
      :if (($Response->"status") = "healthy") do={
        :return true;
      }
    }
    :return false;
  } do={
    :return false;
  }
}

# ============================================================================
# GET CLAUDE RESPONSE
# ============================================================================

:global GetClaudeResponse do={
  :local Command [ :tostr $1 ];
  :global ClaudeRelayURL;
  :global ClaudeRelayTimeout;
  :global CertificateAvailable;
  :global UrlEncode;
  
  :local ProcessURL ($ClaudeRelayURL . "/process-command");
  :local TimeoutNum [:totime $ClaudeRelayTimeout];
  
  # Build JSON request body
  :local RequestBody ("{\"command\":\"" . [$UrlEncode $Command] . "\",\"context\":{}}");
  
  :onerror RequestErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        $ProcessURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        $ProcessURL as-value ]->"data");
    }
    
    :if ([:len $Data] > 0) do={
      :local Response [ :deserialize from=json $Data ];
      :return $Response;
    }
    :return ({success=false; error="Empty response from Claude relay"});
  } do={
    :return ({success=false; error=$RequestErr});
  }
}

# ============================================================================
# PROCESS SMART COMMAND
# ============================================================================

:global ProcessSmartCommand do={
  :local Command [ :tostr $1 ];
  :global ClaudeRelayEnabled;
  :global ClaudeRelayAvailable;
  :global GetClaudeResponse;
  
  # Check if Claude relay is enabled
  :if ($ClaudeRelayEnabled != true) do={
    :return ({success=false; error="Claude relay not enabled"; original_command=$Command});
  }
  
  # Check if service is available
  :if ([$ClaudeRelayAvailable] = false) do={
    :log warning "claude-relay - Service not available";
    :return ({success=false; error="Claude relay service not available"; original_command=$Command});
  }
  
  # Get response from Claude relay
  :local Response [$GetClaudeResponse $Command];
  
  # Check if processing was successful
  :if (($Response->"success") = true) do={
    :local RouterOSCommand ($Response->"routeros_command");
    :log info ("claude-relay - Processed: \"" . $Command . "\" -> \"" . $RouterOSCommand . "\"");
    :return ({success=true; routeros_command=$RouterOSCommand; original_command=$Command});
  } else={
    :local ErrorMsg ($Response->"error");
    :log warning ("claude-relay - Failed: " . $ErrorMsg);
    :return ({success=false; error=$ErrorMsg; original_command=$Command});
  }
}

# ============================================================================
# MODULE LOADED FLAG
# ============================================================================

:global ClaudeRelayLoaded true;
:log info "claude-relay - Module loaded successfully";

