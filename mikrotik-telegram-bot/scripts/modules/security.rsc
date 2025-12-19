#!rsc by RouterOS
# MikroTik Telegram Bot - Security Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Security functions: rate limiting, command validation, user blocking, confirmation flow

# ============================================================================
# DANGEROUS COMMANDS LIST
# ============================================================================

:global DangerousCommands ({
  "/system reset-configuration";
  "/system reset-configuration no-defaults=yes";
  "/system reset-configuration keep-users=yes";
  "/system reset-configuration skip-backup=yes";
  "/file remove *";
  "/file remove all";
});

# ============================================================================
# CHECK IF COMMAND IS DANGEROUS (Blocked)
# ============================================================================

:global IsDangerousCommand do={
  :local Command [ :tostr $1 ];
  :global DangerousCommands;
  
  :local CommandUpper [:toupper $Command];
  :foreach DangerousCmd in=$DangerousCommands do={
    :local DangerousUpper [:toupper $DangerousCmd];
    :if ($CommandUpper ~ ("^" . $DangerousUpper)) do={
      :return true;
    }
  }
  :return false;
}

# ============================================================================
# RATE LIMITING
# ============================================================================

:global CheckRateLimit do={
  :local UserId [ :tostr $1 ];
  :global CommandRateLimit;
  :global CommandRateLimitTracker;
  
  # Initialize tracker if needed
  :if ([:typeof $CommandRateLimitTracker] != "array") do={
    :set CommandRateLimitTracker ({});
  }
  
  :local CurrentTime [:timestamp];
  :local UserKey ("user_" . $UserId);
  :local UserData ($CommandRateLimitTracker->$UserKey);
  
  # Clean up old entries (older than 1 minute)
  :if ([:typeof $UserData] = "array") do={
    :local LastTime ($UserData->"time");
    :local TimeDiff ($CurrentTime - $LastTime);
    :if ($TimeDiff > 60s) do={
      :set ($CommandRateLimitTracker->$UserKey) ({count=1; time=$CurrentTime});
      :return true;
    }
    
    :local Count ($UserData->"count");
    :if ($Count >= $CommandRateLimit) do={
      :return false;
    }
    
    :set ($CommandRateLimitTracker->$UserKey) ({count=($Count + 1); time=($UserData->"time")});
    :return true;
  }
  
  # First command from this user
  :set ($CommandRateLimitTracker->$UserKey) ({count=1; time=$CurrentTime});
  :return true;
}

# ============================================================================
# COMMAND WHITELIST CHECK
# ============================================================================

:global CheckWhitelist do={
  :local Command [ :tostr $1 ];
  :global EnableCommandWhitelist;
  :global CommandWhitelist;
  
  # If whitelist is disabled, allow all
  :if ($EnableCommandWhitelist != true) do={
    :return true;
  }
  
  # Check if command matches any whitelisted command
  :foreach AllowedCmd in=$CommandWhitelist do={
    :if ($Command ~ ("^" . $AllowedCmd)) do={
      :return true;
    }
  }
  
  :return false;
}

# ============================================================================
# CONFIRMATION REQUIRED CHECK
# ============================================================================

:global RequiresConfirmation do={
  :local Command [ :tostr $1 ];
  :global RequireConfirmation;
  :global ConfirmationRequired;
  
  :if ($RequireConfirmation != true) do={
    :return false;
  }
  
  :foreach DangerousCmd in=$ConfirmationRequired do={
    :if ($Command ~ $DangerousCmd) do={
      :return true;
    }
  }
  
  :return false;
}

# ============================================================================
# STORE PENDING CONFIRMATION
# ============================================================================

:global StorePendingConfirmation do={
  :local UserId [ :tostr $1 ];
  :local Command [ :tostr $2 ];
  :local MsgId [ :tostr $3 ];
  :global PendingConfirmations;
  
  :if ([:typeof $PendingConfirmations] != "array") do={
    :set PendingConfirmations ({});
  }
  
  :local ConfirmCode [:rndstr length=6 from="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
  :local UserKey ("user_" . $UserId);
  :set ($PendingConfirmations->$UserKey) ({
    command=$Command;
    code=$ConfirmCode;
    msgid=$MsgId;
    time=[:timestamp]
  });
  
  :return $ConfirmCode;
}

# ============================================================================
# CHECK CONFIRMATION CODE
# ============================================================================

:global CheckConfirmation do={
  :local UserId [ :tostr $1 ];
  :local InputCode [ :tostr $2 ];
  :global PendingConfirmations;
  
  :if ([:typeof $PendingConfirmations] != "array") do={
    :return "";
  }
  
  :local UserKey ("user_" . $UserId);
  :local Pending ($PendingConfirmations->$UserKey);
  
  :if ([:typeof $Pending] != "array") do={
    :return "";
  }
  
  # Check if confirmation is still valid (5 minute timeout)
  :local PendingTime ($Pending->"time");
  :local TimeDiff ([:timestamp] - $PendingTime);
  :if ($TimeDiff > 5m) do={
    :set ($PendingConfirmations->$UserKey) "";
    :return "";
  }
  
  # Check confirmation code
  :if (($Pending->"code") = $InputCode) do={
    :local ConfirmedCmd ($Pending->"command");
    :set ($PendingConfirmations->$UserKey) "";
    :return $ConfirmedCmd;
  }
  
  :return "";
}

# ============================================================================
# CHECK IF USER IS BLOCKED
# ============================================================================

:global IsUserBlocked do={
  :local UserId [ :tostr $1 ];
  :global BlockedUsers;
  :global BlockDuration;
  
  :if ([:typeof $BlockedUsers] != "array") do={
    :return false;
  }
  
  :local UserKey ("user_" . $UserId);
  :local BlockData ($BlockedUsers->$UserKey);
  
  :if ([:typeof $BlockData] != "array") do={
    :return false;
  }
  
  :local BlockTime ($BlockData->"time");
  :local TimeDiff ([:timestamp] - $BlockTime);
  :local BlockDur ([:tonum $BlockDuration] * 60s);
  
  :if ($TimeDiff > $BlockDur) do={
    :set ($BlockedUsers->$UserKey) "";
    :return false;
  }
  
  :return true;
}

# ============================================================================
# RECORD FAILED ATTEMPT
# ============================================================================

:global RecordFailedAttempt do={
  :local UserId [ :tostr $1 ];
  :global BlockedUsers;
  :global MaxFailedAttempts;
  
  :if ([:typeof $BlockedUsers] != "array") do={
    :set BlockedUsers ({});
  }
  
  :local UserKey ("user_" . $UserId);
  :local FailKey ("fails_" . $UserId);
  :local Fails ($BlockedUsers->$FailKey);
  
  :if ([:typeof $Fails] != "num") do={
    :set Fails 0;
  }
  
  :set Fails ($Fails + 1);
  :set ($BlockedUsers->$FailKey) $Fails;
  
  :if ($Fails >= $MaxFailedAttempts) do={
    :set ($BlockedUsers->$UserKey) ({time=[:timestamp]});
    :set ($BlockedUsers->$FailKey) 0;
    :return true;
  }
  
  :return false;
}

# ============================================================================
# CHECK IF USER IS TRUSTED
# ============================================================================

:global IsUserTrusted do={
  :local FromId [ :tostr $1 ];
  :local ChatId [ :tostr $2 ];
  :global TelegramChatId;
  :global TelegramChatIdsTrusted;
  
  # Check primary chat ID
  :if ($FromId = $TelegramChatId || $ChatId = $TelegramChatId) do={
    :return true;
  }
  
  # Check trusted list
  :if ([:len $TelegramChatIdsTrusted] > 0) do={
    # Handle both array and string formats
    :if ([:typeof $TelegramChatIdsTrusted] = "array") do={
      :foreach TrustedId in=$TelegramChatIdsTrusted do={
        :local TrustedIdStr [:tostr $TrustedId];
        :if ($FromId = $TrustedIdStr || $ChatId = $TrustedIdStr) do={
          :return true;
        }
      }
    } else={
      :if ($FromId = $TelegramChatIdsTrusted || $ChatId = $TelegramChatIdsTrusted) do={
        :return true;
      }
    }
  }
  
  :return false;
}

# ============================================================================
# PROCESS CUSTOM COMMAND ALIASES
# ============================================================================

:global ProcessCustomCommand do={
  :local Command [ :tostr $1 ];
  :global CustomCommands;
  
  # Check if command starts with /
  :if ([:pick $Command 0 1] = "/") do={
    :local CmdName [:pick $Command 1 [:len $Command]];
    # Get first word (before any space)
    :local SpacePos [:find $CmdName " "];
    :if ([:typeof $SpacePos] = "num") do={
      :set CmdName [:pick $CmdName 0 $SpacePos];
    }
    :local BaseCmd [:tolower $CmdName];
    
    :if ([:typeof ($CustomCommands->$BaseCmd)] != "nothing") do={
      :return ($CustomCommands->$BaseCmd);
    }
  }
  :return $Command;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global SecurityModuleLoaded true;
:log info "Security module loaded"
