#!rsc by RouterOS
# MikroTik Telegram Bot - Automated Troubleshooting Script
# https://github.com/Danz17/Agent/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Run this script to diagnose common issues

:local ScriptName "troubleshoot"
:put "=========================================="
:put "MikroTik Telegram Bot - Troubleshooting"
:put "=========================================="
:put ""

:local IssuesFound 0
:local Recommendations ({})

# Helper function to add recommendation
:local AddRecommendation do={
  :local Text [:tostr $1]
  :global Recommendations
  :set Recommendations ($Recommendations, $Text)
}

# ============================================================================
# ISSUE 1: Bot Not Responding
# ============================================================================

:put "[Issue 1] Bot Not Responding"
:put "--------------------------------"

# Check scheduler
:local BotScheduler [/system scheduler find where name="telegram-bot"]
:if ([:len $BotScheduler] = 0) do={
  :put "  ✗ Scheduler 'telegram-bot' not found"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Create telegram-bot scheduler: /system scheduler add name=\"telegram-bot\" interval=30s start-time=startup on-event=\"/system script run bot-core\""
} else={
  :local SchedData [/system scheduler get $BotScheduler]
  :if ($SchedData->"disabled" = true) do={
    :put "  ✗ Scheduler is disabled"
    :set IssuesFound ($IssuesFound + 1)
    $AddRecommendation "Enable scheduler: /system scheduler enable telegram-bot"
  } else={
    :if ($SchedData->"run-count" = 0) do={
      :put "  ⚠ Scheduler never ran"
      :set IssuesFound ($IssuesFound + 1)
      $AddRecommendation "Manually run: /system script run bot-core"
    } else={
      :put ("  ✓ Scheduler active (run count: " . ($SchedData->"run-count") . ")")
    }
  }
}

# Check certificate
:if ([:len [/certificate find where common-name~"Go Daddy"]] = 0) do={
  :put "  ✗ SSL certificate missing"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Install certificate: /tool fetch url=\"https://cacerts.digicert.com/GoDaddyRootCertificateAuthorityG2.crt.pem\" mode=https dst-path=godaddy.pem; /certificate import file-name=godaddy.pem passphrase=\"\""
} else={
  :put "  ✓ SSL certificate installed"
}

# Check bot config
:global BotConfigReady
:global TelegramTokenId
:global TelegramChatId

:if ($BotConfigReady != true) do={
  :put "  ✗ Bot configuration not loaded"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Load configuration: /system script run bot-config"
} else={
  :put "  ✓ Bot configuration loaded"
}

:if ($TelegramTokenId = "YOUR_BOT_TOKEN_HERE" || [:len $TelegramTokenId] < 20) do={
  :put "  ✗ Bot token not configured"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Set bot token in bot-config.rsc and re-import"
} else={
  :put "  ✓ Bot token configured"
}

:if ($TelegramChatId = "YOUR_CHAT_ID_HERE" || [:len $TelegramChatId] < 5) do={
  :put "  ✗ Chat ID not configured"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Set chat ID in bot-config.rsc and re-import"
} else={
  :put "  ✓ Chat ID configured"
}

# Check internet connectivity
:put ""
:put "[Issue 2] Internet Connectivity"
:put "--------------------------------"

:onerror ConnErr {
  /tool fetch url="https://1.1.1.1" mode=https output=user
  :put "  ✓ Internet connectivity OK"
} do={
  :put "  ✗ Cannot reach internet"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Check internet connection: /ping 8.8.8.8"
  $AddRecommendation "Check default route: /ip route print where dst-address=0.0.0.0/0"
  $AddRecommendation "Check DNS: /ip dns print"
}

# Check Telegram API
:onerror TelegramErr {
  /tool fetch url="https://api.telegram.org" mode=https output=user
  :put "  ✓ Telegram API reachable"
} do={
  :put "  ✗ Cannot reach Telegram API"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Check if api.telegram.org is accessible"
  $AddRecommendation "Check firewall rules: /ip firewall filter print"
}

# ============================================================================
# ISSUE 3: Commands Not Executing
# ============================================================================

:put ""
:put "[Issue 3] Commands Not Executing"
:put "--------------------------------"

# Check script policies
:local CoreScript [/system script find where name="bot-core"]
:if ([:len $CoreScript] > 0) do={
  :local Policy [/system script get $CoreScript policy]
  :local RequiredPolicies ({"read"; "write"; "policy"; "test"})
  :local PolicyOK true
  
  :foreach Required in=$RequiredPolicies do={
    :if ($Policy !~ $Required) do={
      :set PolicyOK false
    }
  }
  
  :if ($PolicyOK = false) do={
    :put "  ✗ Insufficient script policies"
    :set IssuesFound ($IssuesFound + 1)
    $AddRecommendation "Fix policies: /system script set bot-core policy=ftp,read,write,policy,test,password,sniff,sensitive,romon"
  } else={
    :put "  ✓ Script policies OK"
  }
} else={
  :put "  ✗ bot-core script not found"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Install bot-core script"
}

# Check tmpfs
:onerror TmpErr {
  /file add name="tmpfs/test.txt"
  /file remove "tmpfs/test.txt"
  :put "  ✓ Temporary file system working"
} do={
  :put "  ⚠ Cannot write to tmpfs"
  $AddRecommendation "Check available storage: /system resource print"
}

# ============================================================================
# ISSUE 4: Monitoring Not Working
# ============================================================================

:put ""
:put "[Issue 4] Monitoring Not Working"
:put "--------------------------------"

:global EnableAutoMonitoring
:if ($EnableAutoMonitoring != true) do={
  :put "  ⚠ Monitoring is disabled"
  $AddRecommendation "Enable monitoring: :global EnableAutoMonitoring true"
} else={
  :put "  ✓ Monitoring is enabled"
}

:local MonScheduler [/system scheduler find where name="system-monitoring"]
:if ([:len $MonScheduler] = 0) do={
  :put "  ✗ Monitoring scheduler not found"
  :set IssuesFound ($IssuesFound + 1)
  $AddRecommendation "Create monitoring scheduler"
} else={
  :local MonData [/system scheduler get $MonScheduler]
  :if ($MonData->"disabled" = true) do={
    :put "  ✗ Monitoring scheduler disabled"
    :set IssuesFound ($IssuesFound + 1)
    $AddRecommendation "Enable: /system scheduler enable system-monitoring"
  } else={
    :put ("  ✓ Monitoring scheduler active (run count: " . ($MonData->"run-count") . ")")
  }
}

# ============================================================================
# ISSUE 5: Backups Not Created
# ============================================================================

:put ""
:put "[Issue 5] Backups Not Created"
:put "--------------------------------"

:global EnableAutoBackup
:if ($EnableAutoBackup != true) do={
  :put "  ⚠ Auto backup is disabled"
  $AddRecommendation "Enable backups: :global EnableAutoBackup true"
} else={
  :put "  ✓ Auto backup is enabled"
}

:local BackupScheduler [/system scheduler find where name="auto-backup"]
:if ([:len $BackupScheduler] = 0) do={
  :put "  ⚠ Backup scheduler not found"
  $AddRecommendation "Create backup scheduler"
} else={
  :put "  ✓ Backup scheduler exists"
}

# Check backup files
:local BackupFiles [/file find where name~"\\.backup\$"]
:if ([:len $BackupFiles] = 0) do={
  :put "  ⚠ No backup files found"
  $AddRecommendation "Create manual backup: /system script run modules/backup"
} else={
  :put ("  ✓ Found " . [:len $BackupFiles] . " backup file(s)")
}

# Check disk space
:local Resource [/system resource get]
:local DiskFree ($Resource->"free-hdd-space")
:if ($DiskFree < 10485760) do={
  :put ("  ⚠ Low disk space: " . ($DiskFree / 1048576) . "MB free")
  $AddRecommendation "Clean up old files: /file print; /file remove [find name~\"old-file\"]"
} else={
  :put ("  ✓ Disk space OK: " . ($DiskFree / 1048576) . "MB free")
}

# ============================================================================
# ISSUE 6: High Resource Usage
# ============================================================================

:put ""
:put "[Issue 6] Resource Usage"
:put "--------------------------------"

:local CPU ($Resource->"cpu-load")
:if ($CPU > 80) do={
  :put ("  ⚠ High CPU usage: " . $CPU . "%")
  $AddRecommendation "Check processes: /system resource cpu print"
  $AddRecommendation "Reduce bot polling: /system scheduler set telegram-bot interval=60s"
} else={
  :put ("  ✓ CPU usage OK: " . $CPU . "%")
}

:local MemUsed (($Resource->"total-memory" - $Resource->"free-memory") * 100 / $Resource->"total-memory")
:if ($MemUsed > 90) do={
  :put ("  ⚠ High memory usage: " . $MemUsed . "%")
  $AddRecommendation "Check memory: /system resource print"
  $AddRecommendation "Restart router if needed: /system reboot"
} else={
  :put ("  ✓ Memory usage OK: " . $MemUsed . "%")
}

# ============================================================================
# ISSUE 7: Recent Errors
# ============================================================================

:put ""
:put "[Issue 7] Recent Errors"
:put "--------------------------------"

:local ErrorLogs [/log find where topics~"error" and time>1h]
:if ([:len $ErrorLogs] > 10) do={
  :put ("  ⚠ Found " . [:len $ErrorLogs] . " errors in last hour")
  :put "  Recent errors:"
  :local Count 0
  :foreach LogEntry in=$ErrorLogs do={
    :if ($Count < 5) do={
      :local LogData [/log get $LogEntry]
      :put ("    • " . ($LogData->"message"))
      :set Count ($Count + 1)
    }
  }
  $AddRecommendation "Review full logs: /log print where topics~\"error\""
} else={
  :put ("  ✓ Few errors (" . [:len $ErrorLogs] . " in last hour)")
}

:local ScriptErrors [/log find where topics~"script" and message~"error" and time>1h]
:if ([:len $ScriptErrors] > 0) do={
  :put ("  ⚠ Found " . [:len $ScriptErrors] . " script errors")
  $AddRecommendation "Review script logs: /log print where topics~\"script,error\""
}

# ============================================================================
# ISSUE 8: Token Validity
# ============================================================================

:put ""
:put "[Issue 8] Bot Token Validity"
:put "--------------------------------"

:if ($TelegramTokenId != "YOUR_BOT_TOKEN_HERE" && [:len $TelegramTokenId] > 20) do={
  :onerror TokenErr {
    :local Result [/tool fetch url=("https://api.telegram.org/bot" . $TelegramTokenId . "/getMe") \
      mode=https check-certificate=yes-without-crl output=user as-value]
    :local JSON [:deserialize from=json value=($Result->"data")]
    
    :if ($JSON->"ok" = true) do={
      :put ("  ✓ Bot token valid: @" . ($JSON->"result"->"username"))
    } else={
      :put "  ✗ Bot token invalid"
      :set IssuesFound ($IssuesFound + 1)
      $AddRecommendation "Check bot token with @BotFather"
    }
  } do={
    :put ("  ✗ Token validation failed: " . $TokenErr)
    :set IssuesFound ($IssuesFound + 1)
    $AddRecommendation "Verify token and connectivity"
  }
} else={
  :put "  ⊘ Token not configured"
}

# ============================================================================
# SUMMARY
# ============================================================================

:put ""
:put "=========================================="
:if ($IssuesFound = 0) do={
  :put "✓ NO CRITICAL ISSUES FOUND"
  :put ""
  :put "Your bot appears to be configured correctly."
  :put "If still having issues, try:"
  :put "1. Send '?' to your bot"
  :put "2. Check recent logs: /log print where topics~\"script\""
  :put "3. Manually run: /system script run bot-core"
} else={
  :put ("✗ FOUND " . $IssuesFound . " ISSUE(S)")
  :put ""
  :put "Recommendations:"
  :local Index 1
  :foreach Rec in=$Recommendations do={
    :put ($Index . ". " . $Rec)
    :set Index ($Index + 1)
  }
}
:put "=========================================="
:put ""

:log info ($ScriptName . " - Troubleshooting complete. Issues found: " . $IssuesFound)

