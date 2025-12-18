#!rsc by RouterOS
# MikroTik Telegram Bot - Script Updater
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# Quick script to update all bot scripts from GitHub

:put "=========================================="
:put "MikroTik Telegram Bot - Script Updater"
:put "=========================================="
:put ""

:local BaseURL "https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts"

# Scripts to update
:local Scripts ({
  {name="bot-config"; path="bot-config.rsc"};
  {name="bot-core"; path="bot-core.rsc"};
  {name="modules/backup"; path="modules/backup.rsc"};
  {name="modules/monitoring"; path="modules/monitoring.rsc"};
  {name="modules/custom-commands"; path="modules/custom-commands.rsc"};
  {name="modules/wireless-monitoring"; path="modules/wireless-monitoring.rsc"};
  {name="modules/daily-summary"; path="modules/daily-summary.rsc"};
});

:local UpdatedCount 0;
:local FailedCount 0;

:foreach Script in=$Scripts do={
  :local ScriptName ($Script->"name");
  :local ScriptPath ($Script->"path");
  :local URL ($BaseURL . "/" . $ScriptPath);
  :local TempFile ("update-" . $ScriptName . ".rsc");
  
  :put ("Updating: " . $ScriptName . "...");
  
  :onerror FetchErr {
    /tool/fetch url=$URL dst-path=$TempFile;
    :delay 1s;
    
    :if ([:len [/file find where name=$TempFile]] > 0) do={
      :local ScriptContent [/file get $TempFile contents];
      
      # Check if script exists, create if not
      :if ([:len [/system script find where name=$ScriptName]] = 0) do={
        /system script add name=$ScriptName owner=admin policy=ftp,read,write,policy,test,password,sniff,sensitive,romon source=$ScriptContent;
        :put ("  ✓ Created: " . $ScriptName);
      } else={
        /system script set $ScriptName source=$ScriptContent;
        :put ("  ✓ Updated: " . $ScriptName);
      }
      
      /file remove $TempFile;
      :set UpdatedCount ($UpdatedCount + 1);
    } else={
      :put ("  ✗ Failed: File not downloaded");
      :set FailedCount ($FailedCount + 1);
    }
  } do={
    :put ("  ✗ Failed: " . $FetchErr);
    :set FailedCount ($FailedCount + 1);
  }
}

:put ""
:put "=========================================="
:put ("Updated: " . $UpdatedCount . ", Failed: " . $FailedCount)
:put "=========================================="
:put ""
:put "Run: /system script run bot-config"
