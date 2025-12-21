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

:global ClaudeRelayUseCloud;
:if ([:typeof $ClaudeRelayUseCloud] != "bool") do={
  :set ClaudeRelayUseCloud false;
}

:global ClaudeRelayCloudPort;
:if ([:typeof $ClaudeRelayCloudPort] != "num") do={
  :set ClaudeRelayCloudPort 8899;
}

:global ClaudeRelayHandshakeSecret;
:if ([:typeof $ClaudeRelayHandshakeSecret] != "str") do={
  :set ClaudeRelayHandshakeSecret "";
}

:global ClaudeRelayAutoExecute;
:if ([:typeof $ClaudeRelayAutoExecute] != "bool") do={
  :set ClaudeRelayAutoExecute false;
}

:global ClaudeRelayErrorSuggestions;
:if ([:typeof $ClaudeRelayErrorSuggestions] != "bool") do={
  :set ClaudeRelayErrorSuggestions false;
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
        url=$HealthURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user timeout=$TimeoutNum \
        url=$HealthURL as-value ]->"data");
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
        url=$ProcessURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        url=$ProcessURL as-value ]->"data");
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
# GET ERROR SUGGESTIONS
# ============================================================================

:global GetErrorSuggestions do={
  :local OriginalCommand [ :tostr $1 ];
  :local ErrorMessage [ :tostr $2 ];
  :local CommandOutput [ :tostr $3 ];
  :global ClaudeRelayEnabled;
  :global ClaudeRelayErrorSuggestions;
  :global ClaudeRelayURL;
  :global ClaudeRelayTimeout;
  :global CertificateAvailable;
  :global UrlEncode;
  
  # Check if error suggestions are enabled
  :if ($ClaudeRelayEnabled != true || $ClaudeRelayErrorSuggestions != true) do={
    :return ({success=false; error="Error suggestions not enabled"});
  }
  
  # Check if service is available
  :if ([$ClaudeRelayAvailable] = false) do={
    :return ({success=false; error="Claude relay service not available"});
  }
  
  :local SuggestURL ($ClaudeRelayURL . "/suggest-error-fix");
  :local TimeoutNum [:totime $ClaudeRelayTimeout];
  
  # Build JSON request body
  :local RequestBody ("{\"original_command\":\"" . [$UrlEncode $OriginalCommand] . \
    "\",\"error_message\":\"" . [$UrlEncode $ErrorMessage] . \
    "\",\"command_output\":\"" . [$UrlEncode $CommandOutput] . "\"}");
  
  :onerror RequestErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        url=$SuggestURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        url=$SuggestURL as-value ]->"data");
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
# HANDshake WITH CLOUD SERVICE
# ============================================================================

:global ClaudeRelayHandshake do={
  :global ClaudeRelayURL;
  :global ClaudeRelayTimeout;
  :global ClaudeRelayHandshakeSecret;
  :global Identity;
  :global CertificateAvailable;
  :global UrlEncode;
  
  :local HandshakeURL ($ClaudeRelayURL . "/handshake");
  :local TimeoutNum [:totime $ClaudeRelayTimeout];
  
  # Get router identity
  :local RouterIdentity $Identity;
  :local RouterId [/system identity get name];
  :local Timestamp [:tostr [:timestamp]];
  
  # Build handshake request
  :local RequestBody ("{\"router_identity\":\"" . [$UrlEncode $RouterIdentity] . \
    "\",\"router_id\":\"" . [$UrlEncode $RouterId] . \
    "\",\"timestamp\":\"" . $Timestamp . "\"");
  
  # Add signature if secret is configured
  :if ([:len $ClaudeRelayHandshakeSecret] > 0) do={
    # Note: RouterOS doesn't have HMAC, so signature is optional
    # Python service will validate if secret is set
    :set RequestBody ($RequestBody . ",\"signature\":\"" . $ClaudeRelayHandshakeSecret . "\"");
  }
  
  :set RequestBody ($RequestBody . "}");
  
  :onerror HandshakeErr {
    :local CheckCert [$CertificateAvailable "ISRG Root X1"];
    :local Data;
    :if ($CheckCert = false) do={
      :set Data ([ /tool/fetch check-certificate=no output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        url=$HandshakeURL as-value ]->"data");
    } else={
      :set Data ([ /tool/fetch check-certificate=yes-without-crl output=user http-method=post timeout=$TimeoutNum \
        http-header-field="Content-Type: application/json" \
        http-data=$RequestBody \
        url=$HandshakeURL as-value ]->"data");
    }
    
    :if ([:len $Data] > 0) do={
      :local Response [ :deserialize from=json $Data ];
      :if (($Response->"success") = true) do={
        :log info ("claude-relay - Handshake successful with cloud service");
        :return ({success=true; message=($Response->"message"); cloud_port=($Response->"cloud_port")});
      }
    }
    :return ({success=false; error="Handshake failed"});
  } do={
    :return ({success=false; error=$HandshakeErr});
  }
}

# ============================================================================
# GET CLOUD URL
# ============================================================================

:global GetCloudURL do={
  :global ClaudeRelayUseCloud;
  :global ClaudeRelayCloudPort;
  
  :if ($ClaudeRelayUseCloud != true) do={
    :return "";
  }
  
  # Get cloud IP or DDNS
  :local CloudIP "";
  :local CloudDDNS "";
  
  :onerror CloudErr {
    :local CloudInfo [/ip cloud get];
    :set CloudIP ($CloudInfo->"public-address");
    :set CloudDDNS ($CloudInfo->"ddns-name");
  } do={}
  
  # Prefer DDNS if available, otherwise use cloud IP
  :if ([:len $CloudDDNS] > 0) do={
    :return ("http://" . $CloudDDNS . ":" . [:tostr $ClaudeRelayCloudPort]);
  } else={
    :if ([:len $CloudIP] > 0) do={
      :return ("http://" . $CloudIP . ":" . [:tostr $ClaudeRelayCloudPort]);
    }
  }
  
  :return "";
}

# ============================================================================
# INITIALIZE CLOUD CONNECTION
# ============================================================================

:global ClaudeRelayInitCloud do={
  :global ClaudeRelayUseCloud;
  :global ClaudeRelayHandshake;
  :global GetCloudURL;
  
  :if ($ClaudeRelayUseCloud != true) do={
    :return ({success=false; error="Cloud mode not enabled"});
  }
  
  # Get cloud URL
  :local CloudURL [$GetCloudURL];
  :if ([:len $CloudURL] = 0) do={
    :return ({success=false; error="Cloud IP/DDNS not available"});
  }
  
  # Update ClaudeRelayURL to use cloud
  :global ClaudeRelayURL;
  :set ClaudeRelayURL $CloudURL;
  
  # Perform handshake
  :local HandshakeResult [$ClaudeRelayHandshake];
  :if (($HandshakeResult->"success") = true) do={
    :log info ("claude-relay - Cloud connection established: " . $CloudURL);
    :return ({success=true; url=$CloudURL; message=($HandshakeResult->"message")});
  } else={
    :return ({success=false; error=($HandshakeResult->"error")});
  }
}

# ============================================================================
# MODULE LOADED FLAG
# ============================================================================

:global ClaudeRelayLoaded true;
:log info "claude-relay - Module loaded successfully";

