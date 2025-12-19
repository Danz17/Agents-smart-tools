#!rsc by RouterOS
# MikroTik Telegram Bot - Installation Verification Script
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Run this script to verify your bot installation

:local ScriptName "verify-installation"
:local AllOK true

:put "=========================================="
:put "MikroTik Telegram Bot - Installation Verification"
:put "=========================================="
:put ""

# ============================================================================
# CHECK 1: RouterOS Version
# ============================================================================

:put "[ 1/10] Checking RouterOS version..."
:local ROSVersion [/system resource get version]
:local VersionNum [:pick $ROSVersion 0 [:find $ROSVersion "."]]

:if ([:tonum $VersionNum] >= 7) do={
  :put ("        ✓ RouterOS version OK: " . $ROSVersion)
} else={
  :put ("        ✗ RouterOS version too old: " . $ROSVersion . " (need 7.15+)")
  :set AllOK false
}

# ============================================================================
# CHECK 2: Configuration Variables
# ============================================================================

:put "[ 2/10] Checking configuration variables..."
:global BotConfigReady
:global TelegramTokenId
:global TelegramChatId

:if ([:typeof $BotConfigReady] = "bool" && $BotConfigReady = true) do={
  :put "        ✓ Bot configuration loaded"
} else={
  :put "        ✗ Bot configuration not loaded (run bot-config first)"
  :set AllOK false
}

:if ([:typeof $TelegramTokenId] = "str" && [:len $TelegramTokenId] > 20 && \
     $TelegramTokenId != "YOUR_BOT_TOKEN_HERE") do={
  :put "        ✓ Bot token configured"
} else={
  :put "        ✗ Bot token not configured or invalid"
  :set AllOK false
}

:if ([:typeof $TelegramChatId] = "str" && [:len $TelegramChatId] > 5 && \
     $TelegramChatId != "YOUR_CHAT_ID_HERE") do={
  :put "        ✓ Chat ID configured"
} else={
  :put "        ✗ Chat ID not configured or invalid"
  :set AllOK false
}

# ============================================================================
# CHECK 3: Scripts Installed
# ============================================================================

:put "[ 3/10] Checking installed scripts..."
:local RequiredScripts ({"bot-config"; "bot-core"; "modules/shared-functions"; "modules/telegram-api"; "modules/security"; "modules/monitoring"; "modules/backup"; "modules/custom-commands"; "modules/wireless-monitoring"; "modules/daily-summary"})
:local ScriptsOK 0

:foreach Script in=$RequiredScripts do={
  :if ([:len [/system script find where name=$Script]] > 0) do={
    :set ScriptsOK ($ScriptsOK + 1)
  } else={
    :put ("        ✗ Missing script: " . $Script)
    :set AllOK false
  }
}

:if ($ScriptsOK = [:len $RequiredScripts]) do={
  :put ("        ✓ All scripts installed (" . $ScriptsOK . "/" . [:len $RequiredScripts] . ")")
}

# ============================================================================
# CHECK 4: Schedulers
# ============================================================================

:put "[ 4/10] Checking schedulers..."
:local RequiredSchedulers ({"telegram-bot"; "system-monitoring"; "auto-backup"; "daily-summary"})
:local SchedulersOK 0

:foreach Scheduler in=$RequiredSchedulers do={
  :if ([:len [/system scheduler find where name=$Scheduler]] > 0) do={
    :set SchedulersOK ($SchedulersOK + 1)
  } else={
    :put ("        ⚠ Missing scheduler: " . $Scheduler)
  }
}

:if ($SchedulersOK = [:len $RequiredSchedulers]) do={
  :put ("        ✓ All schedulers configured (" . $SchedulersOK . "/" . [:len $RequiredSchedulers] . ")")
} else={
  :put ("        ⚠ Some schedulers missing (" . $SchedulersOK . "/" . [:len $RequiredSchedulers] . ") - bot may not run automatically")
}

# ============================================================================
# CHECK 5: Certificate
# ============================================================================

:put "[ 5/10] Checking SSL certificate..."
:if ([:len [/certificate find where common-name~"ISRG"]] > 0 || \
    [:len [/certificate find where common-name~"Go Daddy"]] > 0 || \
    [:len [/certificate find where common-name~"DigiCert"]] > 0) do={
  :put "        ✓ SSL certificate installed"
} else={
  :put "        ⚠ SSL certificate missing (will use check-certificate=no)"
}

# ============================================================================
# CHECK 6: Internet Connectivity
# ============================================================================

:put "[ 6/10] Checking internet connectivity..."
:onerror ConnErr {
  :local Result [/tool fetch url="https://api.telegram.org" mode=https output=user as-value]
  :if ($Result->"status" = "finished") do={
    :put "        ✓ Internet connectivity OK"
  } else={
    :put "        ✗ Cannot connect to Telegram API"
    :set AllOK false
  }
} do={
  :put ("        ✗ Internet connectivity test failed: " . $ConnErr)
  :set AllOK false
}

# ============================================================================
# CHECK 7: Bot Token Validation
# ============================================================================

:put "[ 7/10] Validating bot token..."
:if ($TelegramTokenId != "YOUR_BOT_TOKEN_HERE") do={
  :onerror TokenErr {
    :local Result [/tool fetch url=("https://api.telegram.org/bot" . $TelegramTokenId . "/getMe") \
      mode=https output=user as-value]
    :local JSON [:deserialize from=json value=($Result->"data")]
    
    :if ($JSON->"ok" = true) do={
      :put ("        ✓ Bot token valid - Bot name: " . ($JSON->"result"->"first_name"))
    } else={
      :put "        ✗ Bot token invalid or bot not found"
      :set AllOK false
    }
  } do={
    :put ("        ✗ Token validation failed: " . $TokenErr)
    :set AllOK false
  }
} else={
  :put "        ⊘ Skipped (token not configured)"
}

# ============================================================================
# CHECK 8: Disk Space
# ============================================================================

:put "[ 8/10] Checking disk space..."
:local Resource [/system resource get]
:local DiskUsedPercent (($Resource->"total-hdd-space" - $Resource->"free-hdd-space") * 100 / $Resource->"total-hdd-space")

:if ($DiskUsedPercent < 90) do={
  :put ("        ✓ Disk space OK: " . (100 - $DiskUsedPercent) . "% free")
} else={
  :put ("        ⚠ Disk space low: " . $DiskUsedPercent . "% used")
}

# ============================================================================
# CHECK 9: Memory
# ============================================================================

:put "[ 9/10] Checking memory..."
:local MemUsedPercent (($Resource->"total-memory" - $Resource->"free-memory") * 100 / $Resource->"total-memory")

:if ($MemUsedPercent < 90) do={
  :put ("        ✓ Memory OK: " . (100 - $MemUsedPercent) . "% free")
} else={
  :put ("        ⚠ Memory high: " . $MemUsedPercent . "% used")
}

# ============================================================================
# CHECK 10: Script Policies
# ============================================================================

:put "[10/10] Checking script policies..."
:local PolicyOK true
:local RequiredPolicies "ftp,read,write,policy,test"

:foreach Script in=$RequiredScripts do={
  :if ([:len [/system script find where name=$Script]] > 0) do={
    :local ScriptPolicy [/system script get [find name=$Script] policy]
    :if ($ScriptPolicy ~ $RequiredPolicies) do={
      # Policy OK
    } else={
      :put ("        ⚠ Script " . $Script . " may have insufficient policies")
      :set PolicyOK false
    }
  }
}

:if ($PolicyOK = true) do={
  :put "        ✓ Script policies OK"
}

# ============================================================================
# SUMMARY
# ============================================================================

:put ""
:put "=========================================="
:if ($AllOK = true) do={
  :put "✓ VERIFICATION PASSED"
  :put ""
  :put "Your MikroTik Telegram Bot is properly configured!"
  :put ""
  :put "Next steps:"
  :put "1. Send '?' to your bot in Telegram"
  :put "2. You should receive a greeting message"
  :put "3. Try '/help' to see available commands"
  :put "4. Try '/status' to check system status"
} else={
  :put "✗ VERIFICATION FAILED"
  :put ""
  :put "Please fix the issues marked with ✗ above."
  :put "See installation guide for help:"
  :put "https://github.com/yourusername/mikrotik-telegram-bot"
}
:put "=========================================="
:put ""

# ============================================================================
# DETAILED SYSTEM INFO
# ============================================================================

:put "System Information:"
:put "-------------------"
:put ("Identity: " . [/system identity get name])
:put ("Board: " . ($Resource->"board-name"))
:put ("Architecture: " . ($Resource->"architecture-name"))
:put ("CPU: " . ($Resource->"cpu") . " (" . ($Resource->"cpu-count") . " cores)")
:put ("Memory: " . ($Resource->"total-memory" / 1048576) . "MB")
:put ("Storage: " . ($Resource->"total-hdd-space" / 1048576) . "MB")
:put ("Uptime: " . ($Resource->"uptime"))
:put ""

:log info ($ScriptName . " - Verification complete. Result: " . ($AllOK = true ? "PASSED" : "FAILED"))

