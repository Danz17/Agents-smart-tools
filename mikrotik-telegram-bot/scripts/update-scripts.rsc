#!rsc by RouterOS
# MikroTik Telegram Bot - Script Updater
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# Based on patterns from https://github.com/eworm-de/routeros-scripts
# Run: /tool fetch url="https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts/update-scripts.rsc" dst-path=update-scripts.rsc; /import update-scripts.rsc

:local ScriptName "update-scripts";
:local BaseURL "https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts";

:put "==========================================";
:put "MikroTik Telegram Bot - Script Updater";
:put "==========================================";
:put "";

# Script list: name and file path
:local ScriptList {
  "bot-config"="bot-config.rsc";
  "bot-core"="bot-core.rsc";
  "modules/backup"="modules/backup.rsc";
  "modules/monitoring"="modules/monitoring.rsc";
  "modules/custom-commands"="modules/custom-commands.rsc";
  "modules/wireless-monitoring"="modules/wireless-monitoring.rsc";
  "modules/daily-summary"="modules/daily-summary.rsc"
};

:local UpdateCount 0;
:local CreateCount 0;
:local FailCount 0;

:foreach ScriptItem,FilePath in=$ScriptList do={
  :local URL ($BaseURL . "/" . $FilePath);
  :put ("Processing: " . $ScriptItem);
  
  :onerror FetchError {
    :local ScriptContent ([ /tool/fetch check-certificate=no $URL output=user as-value ]->"data");
    
    :if ([:len $ScriptContent] > 100) do={
      :if ([:len [ /system/script/find where name=$ScriptItem ]] > 0) do={
        /system/script/set $ScriptItem source=$ScriptContent;
        :put ("  Updated: " . $ScriptItem);
        :set UpdateCount ($UpdateCount + 1);
      } else={
        /system/script/add name=$ScriptItem owner=admin \
          policy=ftp,read,write,policy,test,password,sniff,sensitive,romon \
          source=$ScriptContent;
        :put ("  Created: " . $ScriptItem);
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
:put "==========================================";
:put ("Created: " . $CreateCount . ", Updated: " . $UpdateCount . ", Failed: " . $FailCount);
:put "==========================================";

:if ($FailCount = 0) do={
  :put "";
  :put "SUCCESS! Now configure your bot:";
  :put "";
  :put ":global TelegramTokenId \"YOUR_BOT_TOKEN\"";
  :put ":global TelegramChatId \"YOUR_CHAT_ID\"";
  :put ":global TelegramChatIdsTrusted \"YOUR_CHAT_ID\"";
  :put ":global BotConfigReady true";
  :put "";
  :put "Then run: /system script run bot-config";
  :put "And test: /system script run bot-core";
} else={
  :put "";
  :put "Some scripts failed. Check network connectivity.";
}
