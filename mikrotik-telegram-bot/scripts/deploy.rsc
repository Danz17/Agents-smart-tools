#!rsc by RouterOS
# MikroTik Telegram Bot - Automated Deployment Script
# https://github.com/Danz17/Agent/tree/main/mikrotik-telegram-bot
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

:if ([:len [/certificate find where common-name~"Go Daddy"]] > 0) do={
  :put "  ✓ Certificate already installed"
} else={
  :onerror CertErr {
    /tool fetch url="https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem" \
      mode=https dst-path=godaddy.pem
    :delay 2s
    /certificate import file-name=godaddy.pem passphrase=""
    :put "  ✓ Certificate installed successfully"
  } do={
    :put ("  ✗ Certificate installation failed: " . $CertErr)
    :set DeploymentFailed true
  }
}

# ============================================================================
# STEP 3: CREATE SCRIPTS
# ============================================================================

:put "[Step 3/8] Creating scripts..."

:local Scripts ({
  "bot-core";
  "modules/monitoring";
  "modules/backup";
  "modules/custom-commands"
})

:local ScriptsCreated 0
:foreach Script in=$Scripts do={
  :local FileName ($Script . ".rsc")
  
  :if ([:len [/file find where name=$FileName]] > 0) do={
    :onerror ScriptErr {
      # Check if script already exists
      :if ([:len [/system script find where name=$Script]] > 0) do={
        :put ("  ⚠ Script already exists: " . $Script)
      } else={
        /system script add name=$Script source=[/file get $FileName contents] \
          policy=ftp,read,write,policy,test,password,sniff,sensitive,romon
        :set ScriptsCreated ($ScriptsCreated + 1)
        :put ("  ✓ Created script: " . $Script)
      }
    } do={
      :put ("  ✗ Failed to create script " . $Script . ": " . $ScriptErr)
      :set DeploymentFailed true
    }
  } else={
    :put ("  ⚠ File not found: " . $FileName)
  }
}

:if ($ScriptsCreated > 0) do={
  :put ("  ✓ Created " . $ScriptsCreated . " script(s)")
}

# ============================================================================
# STEP 4: LOAD CONFIGURATION
# ============================================================================

:put "[Step 4/8] Loading configuration..."

:onerror ConfigErr {
  :if ([:len [/file find where name="bot-config.rsc"]] > 0) do={
    /import bot-config.rsc
    :put "  ✓ Configuration loaded"
  } else={
    :put "  ⚠ bot-config.rsc not found"
    :put "  Please upload and configure bot-config.rsc"
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

# ============================================================================
# STEP 7: TEST CONNECTIVITY
# ============================================================================

:put "[Step 7/8] Testing connectivity..."

:onerror ConnErr {
  /tool fetch url="https://api.telegram.org" mode=https output=user
  :put "  ✓ Telegram API reachable"
} do={
  :put ("  ✗ Cannot reach Telegram API: " . $ConnErr)
  :put "    Check internet connection and firewall"
  :set DeploymentFailed true
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

