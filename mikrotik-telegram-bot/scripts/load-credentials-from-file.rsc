#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Load Credentials from File
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# This script reads credentials from a file on the router and sets them
# Usage: /system script run load-credentials-from-file
#
# File format (stored in /file on router):
#   TELEGRAM_TOKEN_ID=your_token_here
#   TELEGRAM_CHAT_ID=your_chat_id_here
#   TELEGRAM_CHAT_IDS_TRUSTED=your_trusted_ids_here
#
# To create the file on router:
#   /file add name=txmtc-credentials.txt contents="TELEGRAM_TOKEN_ID=your_token\nTELEGRAM_CHAT_ID=your_chat_id\nTELEGRAM_CHAT_IDS_TRUSTED=your_trusted_ids"

:local ScriptName "load-credentials-from-file";
:local CredentialsFile "txmtc-credentials.txt";

# ============================================================================
# READ CREDENTIALS FILE
# ============================================================================

:local CredentialsContent "";
:onerror FileErr {
  :local FileFound [/file/find name=$CredentialsFile];
  :if ([:len $FileFound] > 0) do={
    :set CredentialsContent [/file/get $CredentialsFile contents];
    :log info ($ScriptName . " - Loaded credentials from file");
  } else={
    :put ("ERROR: Credentials file not found: " . $CredentialsFile);
    :put ("Create it with: /file add name=" . $CredentialsFile . " contents=\"TELEGRAM_TOKEN_ID=...\"");
    :error "File not found";
  }
} do={
  :put ("ERROR: Failed to read credentials file: " . $FileErr);
  :error $FileErr;
}

# ============================================================================
# PARSE CREDENTIALS
# ============================================================================

:local botToken "";
:local chatId "";
:local trustedIds "";

# Split by newlines and parse each line
:local Lines {};
:local CurrentLine "";
:for i from=0 to=([:len $CredentialsContent] - 1) do={
  :local Char [:pick $CredentialsContent $i ($i + 1)];
  :if ($Char = "\n" || $Char = "\r") do={
    :if ([:len $CurrentLine] > 0) do={
      :set ($Lines->[:len $Lines]) $CurrentLine;
      :set CurrentLine "";
    }
  } else={
    :set CurrentLine ($CurrentLine . $Char);
  }
}
:if ([:len $CurrentLine] > 0) do={
  :set ($Lines->[:len $Lines]) $CurrentLine;
}

# Parse each line for key=value pairs
:foreach Line in=$Lines do={
  :local EqualPos [:find $Line "="];
  :if ([:typeof $EqualPos] = "num" && $EqualPos > 0) do={
    :local Key [:pick $Line 0 $EqualPos];
    :local Value [:pick $Line ($EqualPos + 1) [:len $Line]];
    
    # Trim whitespace
    :while ([:len $Value] > 0 && [:pick $Value 0 1] = " ") do={
      :set Value [:pick $Value 1 [:len $Value]];
    }
    :while ([:len $Value] > 0 && [:pick $Value ([:len $Value] - 1) [:len $Value]] = " ") do={
      :set Value [:pick $Value 0 ([:len $Value] - 1)];
    }
    
    :if ($Key = "TELEGRAM_TOKEN_ID") do={
      :set botToken $Value;
    }
    :if ($Key = "TELEGRAM_CHAT_ID") do={
      :set chatId $Value;
    }
    :if ($Key = "TELEGRAM_CHAT_IDS_TRUSTED") do={
      :set trustedIds $Value;
    }
  }
}

# ============================================================================
# VALIDATE AND SET CREDENTIALS
# ============================================================================

:if ([:len $botToken] < 10) do={
  :put "ERROR: Invalid or missing TELEGRAM_TOKEN_ID";
  :error "Invalid token";
}

:if ([:len $chatId] < 1) do={
  :put "ERROR: Invalid or missing TELEGRAM_CHAT_ID";
  :error "Invalid chat ID";
}

:if ([:len $trustedIds] < 1) do={
  :set trustedIds $chatId;
  :log warning ($ScriptName . " - Using chat ID as trusted IDs");
}

# Set global variables
:global TelegramTokenId $botToken;
:global TelegramChatId $chatId;
:global TelegramChatIdsTrusted $trustedIds;
:global BotConfigReady true;

:log info ($ScriptName . " - Credentials loaded successfully");

# Create or update startup scheduler to persist credentials
:local schedulerName "telegram-bot-credentials";
:local schedulerScript (":global TelegramTokenId \"" . $botToken . "\"; :global TelegramChatId \"" . $chatId . "\"; :global TelegramChatIdsTrusted \"" . $trustedIds . "\"; :global BotConfigReady true");

:if ([:len [/system scheduler find name=$schedulerName]] > 0) do={
  /system scheduler set [find name=$schedulerName] on-event=$schedulerScript;
  :log info ($ScriptName . " - Updated credentials scheduler");
} else={
  /system scheduler add name=$schedulerName on-event=$schedulerScript start-time=startup;
  :log info ($ScriptName . " - Created credentials scheduler for persistence");
}

:put "";
:put "==========================================";
:put "CREDENTIALS LOADED FROM FILE!";
:put "==========================================";
:put "";
:put ("Bot Token: " . [:pick $botToken 0 10] . "...");
:put ("Chat ID: " . $chatId);
:put ("Trusted IDs: " . $trustedIds);
:put "";
:put "Credentials will persist across reboots.";
:put "";
:put "Now run: /system script run bot-config";
:put "Then run: /system script run bot-core";
:put "";
