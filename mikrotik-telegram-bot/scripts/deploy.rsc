#!rsc by RouterOS
# MikroTik Telegram Bot - Automated Deployment Script
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Run this script to automate installation

:put "=========================================="
:put "MikroTik Telegram Bot - Automated Deployment"
:put "=========================================="
:put ""

:local ScriptName "deploy"
:local DeploymentFailed false

# ============================================================================
# STEP 1: PRE-FLIGHT CHECKS
# ============================================================================

:put "[Step 1/8] Pre-flight checks..."

# Check RouterOS version
:local ROSVersion [/system resource get version]
:local VersionNum [:tonum [:pick $ROSVersion 0 [:find $ROSVersion "."]]]
:if ($VersionNum < 7) do={
  :put "  ✗ RouterOS version too old: $ROSVersion (need 7.15+)"
  :set DeploymentFailed true
} else={
  :put ("  ✓ RouterOS version OK: " . $ROSVersion)
}

# Check available storage
:local Resource [/system resource get]
:local FreeSpace ($Resource->"free-hdd-space")
:if ($FreeSpace < 5242880) do={
  :put ("  ⚠ Low disk space: " . ($FreeSpace / 1048576) . "MB")
} else={
  :put ("  ✓ Disk space OK: " . ($FreeSpace / 1048576) . "MB free")
}

# Check memory
:local FreeMem ($Resource->"free-memory")
:if ($FreeMem < 16777216) do={
  :put ("  ⚠ Low memory: " . ($FreeMem / 1048576) . "MB")
} else={
  :put ("  ✓ Memory OK: " . ($FreeMem / 1048576) . "MB free")
}

:if ($DeploymentFailed = true) do={
  :put ""
  :put "✗ Pre-flight checks failed. Please address issues before deploying."
  :error false
}

# ============================================================================
# STEP 2: INSTALL SSL CERTIFICATE
# ============================================================================

:put "[Step 2/8] Installing SSL certificate..."

:if ([:len [/certificate find where common-name~"Go Daddy"]] > 0 || \
     [:len [/certificate find where common-name~"DigiCert"]] > 0 || \
     [:len [/certificate find where common-name~"ISRG"]] > 0) do={
  :put "  ✓ Certificate already installed"
} else={
  :local CertInstalled false
  # Try multiple certificate sources
  :onerror CertErr1 {
    /tool fetch url="https://letsencrypt.org/certs/isrgrootx1.pem" \
      mode=https dst-path=telegram-cert.pem
    :delay 2s
    /certificate import file-name=telegram-cert.pem passphrase=""
    :set CertInstalled true
    :put "  ✓ Certificate installed (ISRG Root X1)"
  } do={
    :onerror CertErr2 {
      /tool fetch url="https://curl.se/ca/cacert.pem" \
        mode=https dst-path=telegram-cert.pem
      :delay 2s
      /certificate import file-name=telegram-cert.pem passphrase=""
      :set CertInstalled true
      :put "  ✓ Certificate installed (CA Bundle)"
    } do={
      :put "  ⚠ Certificate auto-install failed, trying without verification..."
    }
  }
  :if ($CertInstalled = false) do={
    :put "  ⚠ Will use check-certificate=no for API calls"
  }
}

# ============================================================================
# STEP 3: CREATE SCRIPTS
# ============================================================================

:put "[Step 3/8] Creating scripts..."

:local Scripts ({
  "bot-config";
  "bot-core";
  "verify-installation";
  "troubleshoot";
  "modules/monitoring";
  "modules/backup";
  "modules/custom-commands";
  "modules/wireless-monitoring";
  "modules/daily-summary"
})

:local ScriptsCreated 0
:local ScriptsUpdated 0
:foreach Script in=$Scripts do={
  :local FileName ($Script . ".rsc")
  
  # Support both directory uploads (e.g. "modules/monitoring.rsc") and flat uploads
  # (e.g. "monitoring.rsc" in the root file store).
  :local FoundFile ""
  
  # Try the exact filename first
  :if ([:len [/file find where name=$FileName]] > 0) do={
    :set FoundFile $FileName
  } else={
    # For modules, try the base name without the directory prefix
    :if ($Script ~ "^modules/") do={
      :local BaseName ([:pick $Script 8 [:len $Script]] . ".rsc")
      :if ([:len [/file find where name=$BaseName]] > 0) do={
        :set FoundFile $BaseName
      }
    }
  }

  :if ([:len $FoundFile] > 0) do={
    :onerror ScriptErr {
      :local Existing [/system script find where name=$Script]
      :if ([:len $Existing] > 0) do={
        /system script set $Existing source=[/file get $FoundFile contents] \
          policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
        :set ScriptsUpdated ($ScriptsUpdated + 1)
        :put ("  ✓ Updated script: " . $Script)
      } else={
        /system script add name=$Script source=[/file get $FoundFile contents] \
          policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
        :set ScriptsCreated ($ScriptsCreated + 1)
        :put ("  ✓ Created script: " . $Script)
      }
    } do={
      :put ("  ✗ Failed to create/update script " . $Script . ": " . $ScriptErr)
      :set DeploymentFailed true
    }
  } else={
    :put ("  ⚠ File not found for script: " . $Script)
    :put ("    Expected: " . $FileName)
  }
}

:if (($ScriptsCreated + $ScriptsUpdated) > 0) do={
  :put ("  ✓ Scripts processed - Created: " . $ScriptsCreated . ", Updated: " . $ScriptsUpdated)
}

# ============================================================================
# STEP 4: LOAD CONFIGURATION
# ============================================================================

:put "[Step 4/8] Loading configuration..."

:onerror ConfigErr {
  :if ([:len [/file find where name="bot-config.rsc"]] > 0) do={
    /import bot-config.rsc
    :put "  ✓ Configuration loaded (imported bot-config.rsc)"
  } else={
    :if ([:len [/system script find where name="bot-config"]] > 0) do={
      /system script run bot-config
      :put "  ✓ Configuration loaded (ran script bot-config)"
    } else={
      :put "  ⚠ bot-config.rsc not found and script bot-config missing"
      :put "    Please upload and configure bot-config.rsc"
    }
  }
} do={
  :put ("  ⚠ Configuration load failed: " . $ConfigErr)
}

# ============================================================================
# STEP 5: VERIFY CONFIGURATION
# ============================================================================

:put "[Step 5/8] Verifying configuration..."

:global TelegramTokenId
:global TelegramChatId

:if ([:typeof $TelegramTokenId] = "str" && [:len $TelegramTokenId] > 20 && \
     $TelegramTokenId != "YOUR_BOT_TOKEN_HERE") do={
  :put "  ✓ Bot token configured"
} else={
  :put "  ✗ Bot token not configured"
  :put "    Edit bot-config.rsc and set your token"
  :set DeploymentFailed true
}

:if ([:typeof $TelegramChatId] = "str" && [:len $TelegramChatId] > 5 && \
     $TelegramChatId != "YOUR_CHAT_ID_HERE") do={
  :put "  ✓ Chat ID configured"
} else={
  :put "  ✗ Chat ID not configured"
  :put "    Edit bot-config.rsc and set your chat ID"
  :set DeploymentFailed true
}

# ============================================================================
# STEP 6: CREATE SCHEDULERS
# ============================================================================

:put "[Step 6/8] Creating schedulers..."

# Bot polling scheduler
:if ([:len [/system scheduler find where name="telegram-bot"]] = 0) do={
  :onerror SchedErr {
    /system scheduler add name="telegram-bot" interval=30s start-time=startup \
      policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
      on-event="/system script run bot-core"
    :put "  ✓ Created telegram-bot scheduler"
  } do={
    :put ("  ✗ Failed to create telegram-bot scheduler: " . $SchedErr)
    :set DeploymentFailed true
  }
} else={
  :put "  ⚠ telegram-bot scheduler already exists"
}

# Monitoring scheduler
:if ([:len [/system scheduler find where name="system-monitoring"]] = 0) do={
  :onerror SchedErr {
    /system scheduler add name="system-monitoring" interval=5m start-time=startup \
      policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
      on-event="/system script run modules/monitoring"
    :put "  ✓ Created system-monitoring scheduler"
  } do={
    :put ("  ✗ Failed to create system-monitoring scheduler: " . $SchedErr)
  }
} else={
  :put "  ⚠ system-monitoring scheduler already exists"
}

# Backup scheduler
:if ([:len [/system scheduler find where name="auto-backup"]] = 0) do={
  :onerror SchedErr {
    /system scheduler add name="auto-backup" interval=1d start-time="02:00:00" \
      policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
      on-event="/system script run modules/backup"
    :put "  ✓ Created auto-backup scheduler"
  } do={
    :put ("  ✗ Failed to create auto-backup scheduler: " . $SchedErr)
  }
} else={
  :put "  ⚠ auto-backup scheduler already exists"
}

# Daily summary scheduler
:if ([:len [/system scheduler find where name="daily-summary"]] = 0) do={
  :onerror SchedErr {
    /system scheduler add name="daily-summary" interval=5m start-time=startup \
      policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
      on-event="/system script run modules/daily-summary"
    :put "  ✓ Created daily-summary scheduler"
  } do={
    :put ("  ✗ Failed to create daily-summary scheduler: " . $SchedErr)
  }
} else={
  :put "  ⚠ daily-summary scheduler already exists"
}

# ============================================================================
# STEP 7: TEST CONNECTIVITY
# ============================================================================

:put "[Step 7/8] Testing connectivity..."

# Test with actual bot token if configured
:if ($TelegramTokenId != "YOUR_BOT_TOKEN_HERE" && [:len $TelegramTokenId] > 20) do={
  :onerror ConnErr {
    :local Result [/tool fetch url=("https://api.telegram.org/bot" . $TelegramTokenId . "/getMe") \
      mode=https output=user as-value]
    :put "  ✓ Telegram API reachable (bot token valid)"
  } do={
    :put ("  ⚠ Telegram API test failed: " . $ConnErr)
    :put "    Bot may still work - check token and try manually"
  }
} else={
  # Just test basic HTTPS connectivity
  :onerror ConnErr {
    /tool fetch url="https://www.google.com" mode=https output=none
    :put "  ✓ Internet connectivity OK (configure token to test Telegram)"
  } do={
    :put ("  ✗ No internet connectivity: " . $ConnErr)
    :put "    Check internet connection and firewall"
    :set DeploymentFailed true
  }
}

# ============================================================================
# STEP 8: INITIAL BOT RUN
# ============================================================================

:put "[Step 8/8] Starting bot..."

:if ($DeploymentFailed = false) do={
  :onerror BotErr {
    /system script run bot-core
    :put "  ✓ Bot started successfully"
  } do={
    :put ("  ⚠ Bot start encountered issues: " . $BotErr)
    :put "    Check logs: /log print where topics~\"script\""
  }
} else={
  :put "  ⊘ Skipped due to previous errors"
}

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

:put ""
:put "=========================================="
:if ($DeploymentFailed = false) do={
  :put "✓ DEPLOYMENT SUCCESSFUL"
  :put ""
  :put "Your MikroTik Telegram Bot has been deployed!"
  :put ""
  :put "Next steps:"
  :put "1. Send '?' to your bot in Telegram"
  :put "2. You should receive a greeting message"
  :put "3. Try '/help' to see available commands"
  :put "4. Try '/status' to check system status"
  :put ""
  :put "To verify installation:"
  :put "/system script run verify-installation"
  :put ""
  :put "For troubleshooting:"
  :put "/system script run troubleshoot"
} else={
  :put "✗ DEPLOYMENT INCOMPLETE"
  :put ""
  :put "Some steps failed. Please:"
  :put "1. Review errors above"
  :put "2. Fix configuration issues"
  :put "3. Run deployment again"
  :put ""
  :put "For help:"
  :put "• Check installation guide"
  :put "• Run: /system script run troubleshoot"
  :put "• Review logs: /log print where topics~\"script\""
}
:put "=========================================="
:put ""

:log info ($ScriptName . " - Deployment complete. Success: " . ($DeploymentFailed = false))
