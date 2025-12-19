#!rsc by RouterOS
# MikroTik Telegram Bot - Backup Module
# https://github.com/Danz17/Agents-smart-tools/tree/main/mikrotik-telegram-bot
#
# requires RouterOS, version=7.15
#
# Automated backup creation and management
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ($BotConfigReady != true) \
      do={ :error ("Bot configuration not loaded."); }; } delay=500ms max=50;
  :local ScriptName [ :jobname ];

  # ============================================================================
  # LOAD MODULES
  # ============================================================================

  :global SharedFunctionsLoaded;
  :if ($SharedFunctionsLoaded != true) do={
    :onerror ModErr { /system script run "modules/shared-functions"; } do={ }
  }

  :global TelegramAPILoaded;
  :if ($TelegramAPILoaded != true) do={
    :onerror ModErr { /system script run "modules/telegram-api"; } do={ }
  }

  # ============================================================================
  # IMPORT GLOBALS
  # ============================================================================

  :global Identity;
  :global TelegramTokenId;
  :global TelegramChatId;
  :global TelegramThreadId;
  :global EnableAutoBackup;
  :global BackupRetention;
  :global BackupPassword;
  :global BackupIncludeExport;
  :global BackupAutoSend;
  :global BackupToCloud;

  # Import shared functions
  :global SendTelegram2;
  :global FormatBytes;

  # Check if auto backup is enabled
  :if ($EnableAutoBackup != true) do={
    :log debug ($ScriptName . " - Auto backup is disabled");
    :set ExitOK true;
    :error false;
  }

  # Fallback SendTelegram if module not loaded
  :if ([:typeof $SendTelegram2] != "array") do={
    :global UrlEncode;
    :if ([:typeof $UrlEncode] != "array") do={
      :set UrlEncode do={
        :local String [ :tostr $1 ];
        :local Result "";
        :for I from=0 to=([:len $String] - 1) do={
          :local Char [:pick $String $I ($I + 1)];
          :if ($Char ~ "[A-Za-z0-9_.~-]") do={
            :set Result ($Result . $Char);
          } else={
            :if ($Char = " ") do={ :set Result ($Result . "%20"); }
            :if ($Char = "\n") do={ :set Result ($Result . "%0A"); }
          }
        }
        :return $Result;
      }
    }
    :set SendTelegram2 do={
      :local Notification $1;
      :global TelegramTokenId;
      :global TelegramChatId;
      :global TelegramThreadId;
      :global Identity;
      :global UrlEncode;
      
      :local ChatId ($Notification->"chatid");
      :if ([:len $ChatId] = 0) do={ :set ChatId $TelegramChatId; }
      :local ThreadId ($Notification->"threadid");
      :if ([:len $ThreadId] = 0) do={ :set ThreadId $TelegramThreadId; }
      
      :local Text ("*[" . $Identity . "] " . ($Notification->"subject") . "*\n\n" . \
        ($Notification->"message"));
      :local HTTPData ("chat_id=" . $ChatId . "&disable_notification=" . ($Notification->"silent") . \
        "&message_thread_id=" . $ThreadId . "&parse_mode=Markdown");
      
      :onerror SendErr {
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post \
          ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage") \
          http-data=($HTTPData . "&text=" . [$UrlEncode $Text]);
      } do={ :log warning ("backup - Failed to send notification: " . $SendErr); }
    }
  }

  # Fallback FormatBytes if not loaded
  :if ([:typeof $FormatBytes] != "array") do={
    :set FormatBytes do={
      :local Bytes [:tonum $1];
      :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
      :local UnitIndex 0;
      :while ($Bytes >= 1024 && $UnitIndex < 4) do={
        :set Bytes ($Bytes / 1024);
        :set UnitIndex ($UnitIndex + 1);
      }
      :return ([:tostr $Bytes] . ($Units->$UnitIndex));
    }
  }

  :log info ($ScriptName . " - Starting backup process");

  # ============================================================================
  # GENERATE BACKUP FILENAME
  # ============================================================================
  
  :local DateStr [/system clock get date];
  :local TimeStr [/system clock get time];
  # Clean up time string (remove colons)
  :local TimeClean "";
  :for I from=0 to=([:len $TimeStr] - 1) do={
    :local Char [:pick $TimeStr $I ($I + 1)];
    :if ($Char != ":") do={
      :set TimeClean ($TimeClean . $Char);
    }
  }
  :local BackupName ($Identity . "-" . $DateStr . "-" . $TimeClean);

  # ============================================================================
  # CREATE BINARY BACKUP
  # ============================================================================
  
  :local BackupFile ($BackupName . ".backup");
  :local BackupCreated false;
  
  :onerror BackupErr {
    :if ([:len $BackupPassword] > 0) do={
      /system backup save name=$BackupName password=$BackupPassword encryption=aes-sha256;
    } else={
      /system backup save name=$BackupName dont-encrypt=yes;
    }
    :delay 2s;
    :set BackupCreated true;
    :log info ($ScriptName . " - Binary backup created: " . $BackupFile);
  } do={
    :log error ($ScriptName . " - Failed to create binary backup: " . $BackupErr);
    $SendTelegram2 ({ origin=$ScriptName; silent=false; \
      subject="❌ Backup Failed"; \
      message=("Failed to create binary backup on " . $Identity . "\n\nError: " . $BackupErr) });
  }

  # ============================================================================
  # CREATE EXPORT FILE (if enabled)
  # ============================================================================
  
  :local ExportFile "";
  :local ExportCreated false;
  
  :if ($BackupIncludeExport = true && $BackupCreated = true) do={
    :set ExportFile ($BackupName . ".rsc");
    :onerror ExportErr {
      /export file=$BackupName;
      :delay 2s;
      :set ExportCreated true;
      :log info ($ScriptName . " - Export created: " . $ExportFile);
    } do={
      :log warning ($ScriptName . " - Failed to create export: " . $ExportErr);
    }
  }

  # ============================================================================
  # BACKUP TO CLOUD (if enabled)
  # ============================================================================
  
  :if ($BackupToCloud = true && $BackupCreated = true) do={
    :onerror CloudErr {
      /system backup cloud upload-file action=create-and-upload password="" replace=($BackupName . ".backup");
      :log info ($ScriptName . " - Backup uploaded to cloud");
    } do={
      :log warning ($ScriptName . " - Cloud upload failed: " . $CloudErr);
    }
  }

  # ============================================================================
  # GET BACKUP FILE INFO
  # ============================================================================
  
  :local BackupSize 0;
  :local ExportSize 0;
  
  :onerror FileErr {
    :if ([:len [/file find name=$BackupFile]] > 0) do={
      :set BackupSize [/file get [find name=$BackupFile] size];
    }
    :if ($ExportCreated = true && [:len [/file find name=$ExportFile]] > 0) do={
      :set ExportSize [/file get [find name=$ExportFile] size];
    }
  } do={ }

  # ============================================================================
  # BACKUP ROTATION (cleanup old backups)
  # ============================================================================
  
  :if ([:typeof $BackupRetention] = "num" && $BackupRetention > 0) do={
    :local BackupFiles [/file find where name~("\\.backup\$") type="backup"];
    :local BackupCount [:len $BackupFiles];
    
    :if ($BackupCount > $BackupRetention) do={
      :local ToDelete ($BackupCount - $BackupRetention);
      :log info ($ScriptName . " - Removing " . $ToDelete . " old backup(s)");
      
      # Sort by creation time and remove oldest
      :local Deleted 0;
      :foreach File in=$BackupFiles do={
        :if ($Deleted < $ToDelete) do={
          :local FileName [/file get $File name];
          # Don't delete the backup we just created
          :if ($FileName != $BackupFile) do={
            :onerror DelErr {
              /file remove $File;
              :set Deleted ($Deleted + 1);
              :log info ($ScriptName . " - Removed old backup: " . $FileName);
            } do={ }
          }
        }
      }
    }
    
    # Also clean up old exports
    :if ($BackupIncludeExport = true) do={
      :local ExportFiles [/file find where name~("\\.rsc\$") type="script"];
      :local ExportCount [:len $ExportFiles];
      
      :if ($ExportCount > $BackupRetention) do={
        :local ToDelete ($ExportCount - $BackupRetention);
        :local Deleted 0;
        :foreach File in=$ExportFiles do={
          :if ($Deleted < $ToDelete) do={
            :local FileName [/file get $File name];
            :if ($FileName != $ExportFile && $FileName ~ "^" . $Identity) do={
              :onerror DelErr {
                /file remove $File;
                :set Deleted ($Deleted + 1);
              } do={ }
            }
          }
        }
      }
    }
  }

  # ============================================================================
  # SEND NOTIFICATION
  # ============================================================================
  
  :if ($BackupCreated = true) do={
    :local NotifyMsg ("✅ Backup completed successfully\n\n");
    :set NotifyMsg ($NotifyMsg . "📁 *Binary Backup:*\n");
    :set NotifyMsg ($NotifyMsg . "  File: `" . $BackupFile . "`\n");
    :set NotifyMsg ($NotifyMsg . "  Size: " . [$FormatBytes $BackupSize] . "\n");
    :if ([:len $BackupPassword] > 0) do={
      :set NotifyMsg ($NotifyMsg . "  🔐 Encrypted\n");
    }
    
    :if ($ExportCreated = true) do={
      :set NotifyMsg ($NotifyMsg . "\n📄 *Export File:*\n");
      :set NotifyMsg ($NotifyMsg . "  File: `" . $ExportFile . "`\n");
      :set NotifyMsg ($NotifyMsg . "  Size: " . [$FormatBytes $ExportSize] . "\n");
    }
    
    :if ($BackupToCloud = true) do={
      :set NotifyMsg ($NotifyMsg . "\n☁️ Uploaded to MikroTik Cloud\n");
    }
    
    :local BackupFiles [/file find where name~"\\.backup\$"];
    :set NotifyMsg ($NotifyMsg . "\n💾 Total backups stored: " . [:len $BackupFiles]);
    
    $SendTelegram2 ({ origin=$ScriptName; silent=true; \
      subject="💾 Backup Complete"; \
      message=$NotifyMsg });
  }

  :log info ($ScriptName . " - Backup process completed");
  :set ExitOK true;

} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Backup failed: " . $Err);
  }
}

# ============================================================================
# BACKUP COMMAND HANDLER
# ============================================================================

:global CommandBackup do={
  :local Action [:tostr $1];
  :global Identity;
  :global FormatBytes;
  
  # Ensure FormatBytes exists
  :if ([:typeof $FormatBytes] != "array") do={
    :set FormatBytes do={
      :local Bytes [:tonum $1];
      :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
      :local UnitIndex 0;
      :while ($Bytes >= 1024 && $UnitIndex < 4) do={
        :set Bytes ($Bytes / 1024);
        :set UnitIndex ($UnitIndex + 1);
      }
      :return ([:tostr $Bytes] . ($Units->$UnitIndex));
    }
  }
  
  :if ($Action = "now" || [:len $Action] = 0) do={
    :onerror BackupErr {
      /system script run "modules/backup";
      :return "💾 Backup started! You will receive a notification when complete.";
    } do={
      :return ("❌ Failed to start backup: " . $BackupErr);
    }
  }
  
  :if ($Action = "list") do={
    :local BackupMsg ("💾 *Available Backups*\n\n");
    :local BackupCount 0;
    
    :foreach File in=[/file find where name~"\\.backup\$"] do={
      :local FileData [/file get $File];
      :set BackupCount ($BackupCount + 1);
      :set BackupMsg ($BackupMsg . "• " . ($FileData->"name") . "\n");
      :set BackupMsg ($BackupMsg . "   Size: " . [$FormatBytes ($FileData->"size")]);
      :set BackupMsg ($BackupMsg . " | Date: " . ($FileData->"creation-time") . "\n");
    }
    
    :if ($BackupCount = 0) do={
      :set BackupMsg ($BackupMsg . "_No backup files found_");
    }
    
    :return $BackupMsg;
  }
  
  :return "Usage: `/backup [now|list]`";
}
