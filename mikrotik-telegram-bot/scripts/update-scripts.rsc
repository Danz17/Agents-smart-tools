#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Script Updater / Installer
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# Based on patterns from https://github.com/eworm-de/routeros-scripts
# Run: /tool fetch url="https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts/update-scripts.rsc" dst-path=update-scripts.rsc; /import update-scripts.rsc
#
# Features:
# - Configurable GitHub source (user/repo/branch/path) for forks
# - Auto-detects existing installation prefix (e.g., "bot/", "telegram/")
# - Wildcard matching finds scripts in nested folder structures
# - Falls back to exact match, then regex pattern matching

:local ScriptName "update-scripts";

# ============================================================================
# CONFIGURABLE PATHS - Adjust these for custom installations
# ============================================================================

# GitHub repository settings (change for forks or different branches)
:local GitHubUser "Danz17";
:local GitHubRepo "Agents-smart-tools";
:local GitHubBranch "main";
:local GitHubPath "mikrotik-telegram-bot/scripts";

# Build base URL dynamically
:local BaseURL ("https://raw.githubusercontent.com/" . $GitHubUser . "/" . $GitHubRepo . "/" . $GitHubBranch . "/" . $GitHubPath);

# Local script name prefix (for nested installations)
# Examples: "" for flat, "bot/" for /system/script name=bot/bot-core, etc.
:local LocalPrefix "";

# Auto-detect existing installation prefix
:onerror DetectErr {
  :local ExistingScript [ /system/script/find where name~"bot-core" ];
  :if ([:len $ExistingScript] > 0) do={
    :local ExistingName [ /system/script/get $ExistingScript name ];
    :local CorePos [:find $ExistingName "bot-core"];
    :if ([:typeof $CorePos] = "num" && $CorePos > 0) do={
      :set LocalPrefix [:pick $ExistingName 0 $CorePos];
      :put ("Auto-detected prefix: " . $LocalPrefix);
    }
  }
} do={ }

:put "";
:put "+===============================================================+";
:put "|  ____  _   _ _____ _   _ _____  __                            |";
:put "| |  _ \\| | | | ____| \\ | |_ _\\ \\/ /                            |";
:put "| | |_) | |_| |  _| |  \\| || | \\  /                             |";
:put "| |  __/|  _  | |___| |\\  || | /  \\                             |";
:put "| |_|   |_| |_|_____|_| \\_|___/_/\\_\\                            |";
:put "+---------------------------------------------------------------+";
:put "|  TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent     |";
:put "|  Crafted with love & frustration                             |";
:put "+===============================================================+";
:put "";
:put ("  Source: " . $BaseURL);
:if ([:len $LocalPrefix] > 0) do={ :put ("  Prefix: " . $LocalPrefix); }
:put "";

# Script list: base name and relative file path (order matters - core modules first!)
# Format: "script-name"="relative/path.rsc"
:local ScriptList {
  "bot-config"="bot-config.rsc";
  "modules/shared-functions"="modules/shared-functions.rsc";
  "modules/telegram-api"="modules/telegram-api.rsc";
  "modules/security"="modules/security.rsc";
  "bot-core"="bot-core.rsc";
  "modules/backup"="modules/backup.rsc";
  "modules/monitoring"="modules/monitoring.rsc";
  "modules/custom-commands"="modules/custom-commands.rsc";
  "modules/wireless-monitoring"="modules/wireless-monitoring.rsc";
  "modules/daily-summary"="modules/daily-summary.rsc";
  "set-credentials"="set-credentials.rsc"
};

:local UpdateCount 0;
:local CreateCount 0;
:local FailCount 0;

:foreach ScriptItem,FilePath in=$ScriptList do={
  :local URL ($BaseURL . "/" . $FilePath);
  :local FullScriptName ($LocalPrefix . $ScriptItem);
  :put ("Processing: " . $FullScriptName);

  :onerror FetchError {
    :local ScriptContent ([ /tool/fetch check-certificate=yes-without-crl $URL output=user as-value ]->"data");

    :if ([:len $ScriptContent] > 100) do={
      # Try to find existing script with exact name or wildcard match
      :local ExistingScript [ /system/script/find where name=$FullScriptName ];

      # If not found, try wildcard search for scripts ending with this name
      :if ([:len $ExistingScript] = 0) do={
        :local WildcardPattern (".*" . $ScriptItem . "\$");
        :set ExistingScript [ /system/script/find where name~$WildcardPattern ];
      }

      :if ([:len $ExistingScript] > 0) do={
        # Update first matching script
        :local TargetScript [:pick $ExistingScript 0];
        :local ActualName [ /system/script/get $TargetScript name ];
        /system/script/set $TargetScript source=$ScriptContent;
        :put ("  Updated: " . $ActualName);
        :set UpdateCount ($UpdateCount + 1);
      } else={
        /system/script/add name=$FullScriptName owner=admin \
          policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
          source=$ScriptContent;
        :put ("  Created: " . $FullScriptName);
        :set CreateCount ($CreateCount + 1);
      }
    } else={
      :put ("  FAILED: Empty or invalid content");
      :set FailCount ($FailCount + 1);
    }
  } do={
    :put ("  FAILED: " . $FetchError);
    :set FailCount ($FailCount + 1);
  }
}

:put "";
:put "+---------------------------------------------------------------+";
:put ("| Created: " . $CreateCount . " | Updated: " . $UpdateCount . " | Failed: " . $FailCount);
:put "+---------------------------------------------------------------+";

:if ($FailCount = 0) do={
  :put "";
  :put "  SUCCESS! Configure your bot:";
  :put "";
  :put "  :global TelegramTokenId \"YOUR_BOT_TOKEN\"";
  :put "  :global TelegramChatId \"YOUR_CHAT_ID\"";
  :put "  :global TelegramChatIdsTrusted \"YOUR_CHAT_ID\"";
  :put "  :global BotConfigReady true";
  :put "";
  :put "  Then: /system script run bot-config";
  :put "  Test: /system script run bot-core";
  :put "";
  :put "  --- TxMTC by P\CC\B6h\CC\B6e\CC\B6n\CC\B6i\CC\B6x\CC\B6 ---";
} else={
  :put "";
  :put "  Some scripts failed. Check network connectivity.";
}
