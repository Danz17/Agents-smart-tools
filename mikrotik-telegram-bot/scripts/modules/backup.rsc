#!rsc by RouterOS
# MikroTik Telegram Bot - Backup Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Automated backup creation and management

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # Import configuration
  :global Identity;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableAutoBackup;
  :global BackupRetention;
  :global BackupPassword;
  :global BackupIncludeExport;

  # Check if backup is enabled
  :if ($EnableAutoBackup != true) do={
    :log debug ($ScriptName . " - Auto backup is disabled");
    :set ExitOK true;
    :error false;
  }

  # Default retention to 7 if not set
  :if ([:typeof $BackupRetention] != "num") do={
    :set BackupRetention 7;
  }

  # URL encode helper
  :local UrlEncode do={
    :local String [ :tostr $1 ];
    :local Result "";
    :for I from=0 to=([:len $String] - 1) do={
      :local Char [:pick $String $I ($I + 1)];
      :if ($Char ~ "[A-Za-z0-9_.~-]") do={
        :set Result ($Result . $Char);
      } else={
        :if ($Char = " ") do={
          :set Result ($Result . "%20");
        } else={
          :if ($Char = "\n") do={
            :set Result ($Result . "%0A");
          } else={
            :set Result ($Result . $Char);
          }
        }
      }
    }
    :return $Result;
  }

  # Send notification function
  :local SendTelegram2 do={
    :local Notification $1;
    :global TelegramTokenId;
    :global TelegramChatId;
    :global TelegramThreadId;
    :global Identity;
    
    :local ChatId ([$1 "chatid"]);
    :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
    
    :local ThreadId ([$1 "threadid"]);
    :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
    
    :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . \
      ($Notification->"message"));
    
    :local HTTPData ("chat_id=" . $ChatId . \
      "&disable_notification=" . ($Notification->"silent") . \
      "&message_thread_id=" . $ThreadId . \
      "&parse_mode=Markdown");
    
    :onerror SendErr {
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
        ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
        http-data=($HTTPData . "&text=" . [$UrlEncode $Text]);
    } do={
      :log warning ("backup - Failed to send notification: " . $SendErr);
    }
  }

  # Format bytes to human readable
  :local FormatBytes do={
    :local Bytes [:tonum $1];
    :local Units ({"B"; "KB"; "MB"; "GB"});
    :local UnitIndex 0;
    
    :while ($Bytes >= 1024 && $UnitIndex < 3) do={
      :set Bytes ($Bytes / 1024);
      :set UnitIndex ($UnitIndex + 1);
    }
    
    :return ([:tostr $Bytes] . ($Units->$UnitIndex));
  }

  :log info ($ScriptName . " - Starting backup process");

  # Check disk space before backup (need at least 10MB free)
  :local FreeSpace [/system resource get free-hdd-space];
  :if ($FreeSpace < 10000000) do={
    :log error ($ScriptName . " - Insufficient disk space: " . $FreeSpace . " bytes free");
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="❌ Backup Failed"; \
      message=("Insufficient disk space for backup\n\n" . \
        "Free space: " . [$FormatBytes $FreeSpace] . "\n" . \
        "Required: 10MB minimum") });
    :set ExitOK true;
    :error false;
  }

  # Create backup filename
  :local DateStr [/system clock get date];
  :local BackupName ($Identity . "-" . $DateStr);
  :local BackupFile ($BackupName . ".backup");
  :local BackupSuccess false;
  
  :onerror BackupErr {
    :if ([:len $BackupPassword] > 0) do={
      /system backup save name=$BackupName password=$BackupPassword encryption=aes-sha256;
    } else={
      /system backup save name=$BackupName dont-encrypt=yes;
    }
    :delay 2s;
    
    :if ([:len [/file find where name=$BackupFile]] > 0) do={
      :set BackupSuccess true;
      :log info ($ScriptName . " - Backup created: " . $BackupFile);
    }
  } do={
    :log error ($ScriptName . " - Backup failed: " . $BackupErr);
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="❌ Backup Failed"; \
      message=("Failed to create backup\n\nError: " . $BackupErr) });
  }

  # Create export if enabled
  :local ExportFile "";
  :if ($BackupIncludeExport = true && $BackupSuccess = true) do={
    :set ExportFile ($BackupName . ".rsc");
    :onerror ExportErr {
      /export file=$BackupName;
      :delay 1s;
      :log info ($ScriptName . " - Export created: " . $ExportFile);
    } do={
      :log warning ($ScriptName . " - Export failed: " . $ExportErr);
    }
  }

  # Cleanup old backups (sorted by creation-time, oldest first)
  :local BackupFiles [/file find where name~("^" . $Identity . ".*\\.backup\$")];
  :local BackupCount [:len $BackupFiles];
  :local DeletedCount 0;
  
  :if ($BackupCount > $BackupRetention) do={
    :local ToDelete ($BackupCount - $BackupRetention);
    # Build array of files with creation times
    :local FileTimes ({});
    :foreach File in=$BackupFiles do={
      :local FileCreationTime [/file get $File creation-time];
      :set ($FileTimes->[:len $FileTimes]) {file=$File; time=$FileCreationTime};
    }
    # Find and delete oldest files (simple selection sort)
    :while ($DeletedCount < $ToDelete && [:len $FileTimes] > 0) do={
      :local OldestIndex 0;
      :local OldestTime ($FileTimes->0->"time");
      :local I 0;
      :foreach Entry in=$FileTimes do={
        :local EntryTime ($Entry->"time");
        :if ($EntryTime < $OldestTime) do={
          :set OldestTime $EntryTime;
          :set OldestIndex $I;
        }
        :set I ($I + 1);
      }
      # Delete the oldest file
      :local OldestEntry ($FileTimes->$OldestIndex);
      :local File ($OldestEntry->"file");
      :local FileName [/file get $File name];
      /file remove $File;
      :set DeletedCount ($DeletedCount + 1);
      :log info ($ScriptName . " - Deleted old backup: " . $FileName);
      # Remove from array
      :local NewFileTimes ({});
      :local J 0;
      :foreach Entry in=$FileTimes do={
        :if ($J != $OldestIndex) do={
          :set ($NewFileTimes->[:len $NewFileTimes]) $Entry;
        }
        :set J ($J + 1);
      }
      :set FileTimes $NewFileTimes;
    }
  }

  # Send notification
  :if ($BackupSuccess = true) do={
    :local BackupSize [/file get [find name=$BackupFile] size];
    
    :local BackupMsg ("💾 Backup created successfully\n\n" . \
      "📁 File: " . $BackupFile . "\n" . \
      "📊 Size: " . [$FormatBytes $BackupSize]);
    
    :if ($DeletedCount > 0) do={
      :set BackupMsg ($BackupMsg . "\n🗑️ Cleaned: " . $DeletedCount . " old backup(s)");
    }
    
    $SendTelegram2 ({ origin=$ScriptName; silent=true; \
      subject="💾 Backup Complete"; message=$BackupMsg });
  }

  :log info ($ScriptName . " - Backup process completed");
  :set ExitOK true;
  
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Backup module failed: " . $Err);
  }
}
