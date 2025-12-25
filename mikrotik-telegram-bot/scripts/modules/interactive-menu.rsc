#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Interactive Menu Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Interactive menu system with inline keyboards for Telegram
# Dependencies: shared-functions, telegram-api, script-registry

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr { /system script run "modules/shared-functions"; } do={ }
}

:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror LoadErr { /system script run "modules/telegram-api"; } do={ }
}

:global ScriptRegistryLoaded;
:if ($ScriptRegistryLoaded != true) do={
  :onerror LoadErr { /system script run "modules/script-registry"; } do={ }
}

# Import functions
:global SendTelegram2;
:global ListScriptsByCategory;
:global GetCategories;
:global GetScriptInfo;
:global SearchScripts;
:global UrlEncode;
:global CertificateAvailable;

# ============================================================================
# CREATE INLINE KEYBOARD
# ============================================================================

:global CreateInlineKeyboard do={
  :local Buttons $1;
  :local Keyboard ({});
  
  :foreach Row in=$Buttons do={
    :local KeyboardRow ({});
    :foreach Button in=$Row do={
      :local ButtonData ({
        text=($Button->"text");
        callback_data=($Button->"callback_data")
      });
      :set ($KeyboardRow->[:len $KeyboardRow]) $ButtonData;
    }
    :set ($Keyboard->[:len $Keyboard]) $KeyboardRow;
  }
  
  :return [ :serialize to=json value=({inline_keyboard=$Keyboard}) ];
}

# ============================================================================
# SEND MESSAGE WITH INLINE KEYBOARD
# ============================================================================

:global SendTelegramWithKeyboard do={
  :local ChatId [ :tostr $1 ];
  :local MessageText [ :tostr $2 ];
  :local KeyboardJSON [ :tostr $3 ];
  :local ThreadId [ :tostr $4 ];
  
  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;
  
  :local SendUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage");
  :local SendData ("chat_id=" . $ChatId . "&text=" . [$UrlEncode $MessageText] . "&parse_mode=MarkdownV2" . "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
  
  :if ([:len $ThreadId] > 0 && $ThreadId != "0") do={
    :set SendData ($SendData . "&message_thread_id=" . $ThreadId);
  }
  
  :onerror SendErr {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no output=none http-method=post $SendUrl http-data=$SendData;
    } else={
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post $SendUrl http-data=$SendData;
    }
    :return true;
  } do={
    :log warning ("SendTelegramWithKeyboard - Failed: " . $SendErr);
    :return false;
  }
}

# ============================================================================
# CREATE COMMAND BUTTONS (Helper for common commands)
# ============================================================================

:global CreateCommandButtons do={
  :local Commands $1;  # Array of command strings (can be nested)
  :local Result ({});
  :local Row ({});
  :local Count 0;
  
  # Handle nested arrays (e.g., {{"/status"; "/interfaces"}})
  :foreach CmdOrArray in=$Commands do={
    :if ([:typeof $CmdOrArray] = "array") do={
      # Nested array - process each command
      :foreach Cmd in=$CmdOrArray do={
        :set ($Row->[:len $Row]) ({text=$Cmd; callback_data=("cmd:" . $Cmd)});
        :set Count ($Count + 1);
        :if ($Count = 2) do={
          :set ($Result->[:len $Result]) $Row;
          :set Row ({});
          :set Count 0;
        }
      }
    } else={
      # Single command string
      :set ($Row->[:len $Row]) ({text=$CmdOrArray; callback_data=("cmd:" . $CmdOrArray)});
      :set Count ($Count + 1);
      :if ($Count = 2) do={
        :set ($Result->[:len $Result]) $Row;
        :set Row ({});
        :set Count 0;
      }
    }
  }
  :if ($Count > 0) do={
    :set ($Result->[:len $Result]) $Row;
  }
  :return $Result;
}

# ============================================================================
# SHOW MAIN MENU
# ============================================================================

:global ShowMainMenu do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];
  :local ThreadId [ :tostr $3 ];
  
  :local Categories [$GetCategories];
  :local Buttons ({});
  
  # Category buttons (2 per row)
  :local CurrentRow ({});
  :local RowCount 0;
  :foreach Cat in=$Categories do={
    :local CatName $Cat;
    # Use display names for categories
    :if ($Cat = "monitoring") do={ :set CatName "Monitoring"; }
    :if ($Cat = "backup") do={ :set CatName "Backup"; }
    :if ($Cat = "utilities") do={ :set CatName "Utilities"; }
    :if ($Cat = "parental-control") do={ :set CatName "Parental Control"; }
    :if ($Cat = "network-management") do={ :set CatName "Network Management"; }
    :if ($Cat = "misc") do={ :set CatName "Misc"; }
    :local Emoji "";
    :if ($Cat = "monitoring") do={ :set Emoji "📊"; }
    :if ($Cat = "backup") do={ :set Emoji "💾"; }
    :if ($Cat = "utilities") do={ :set Emoji "🔧"; }
    :if ($Cat = "parental-control") do={ :set Emoji "🛡️"; }
    :if ($Cat = "network-management") do={ :set Emoji "🌐"; }
    :if ($Cat = "misc") do={ :set Emoji "📦"; }
    
    :set ($CurrentRow->[:len $CurrentRow]) ({
      text=($Emoji . " " . $CatName);
      callback_data=("cat:" . $Cat)
    });
    :set RowCount ($RowCount + 1);
    :if ($RowCount >= 2) do={
      :set ($Buttons->[:len $Buttons]) $CurrentRow;
      :set CurrentRow ({});
      :set RowCount 0;
    }
  }
  :if ([:len $CurrentRow] > 0) do={
    :set ($Buttons->[:len $Buttons]) $CurrentRow;
  }
  
  # Action buttons
  :set ($Buttons->[:len $Buttons]) ({
    {text="📥 Install Script"; callback_data="menu:install"};
    {text="🔍 Search"; callback_data="menu:search"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {text="⚙️ Settings"; callback_data="menu:settings"};
    {text="📊 Monitoring"; callback_data="cmd:/monitoring-settings"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {text="❌ Close"; callback_data="menu:close"}
  });
  
  :local KeyboardJSON [$CreateInlineKeyboard $Buttons];
  :local MenuText ("*⚡ TxMTC Menu*\n\nSelect a category:");
  
  :global TelegramTokenId;
  :local APIUrl ("https://api.telegram.org/bot" . $TelegramTokenId);
  
  :if ([:len $MessageId] > 0 && $MessageId != "0") do={
    # Edit existing message
    :local EditUrl ($APIUrl . "/editMessageText");
    :local HTTPData ("chat_id=" . $ChatId . \
      "&message_id=" . $MessageId . \
      "&text=" . [$UrlEncode $MenuText] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
    
    :onerror EditErr {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
      }
    } do={
      :log warning ("interactive-menu - Failed to edit message: " . $EditErr);
    }
  } else={
    # Send new message with keyboard
    :global TelegramTokenId;
    :local SendUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/sendMessage");
    :local SendData ("chat_id=" . $ChatId . \
      "&text=" . [$UrlEncode $MenuText] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
    :if ([:len $ThreadId] > 0) do={
      :set SendData ($SendData . "&message_thread_id=" . $ThreadId);
    }
    
    :onerror SendErr {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $SendUrl http-data=$SendData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $SendUrl http-data=$SendData;
      }
    } do={
      :log warning ("interactive-menu - Failed to send menu: " . $SendErr);
    }
  }
}

# ============================================================================
# SHOW CATEGORY MENU
# ============================================================================

:global ShowCategoryMenu do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];
  :local ThreadId [ :tostr $3 ];
  :local Category [ :tostr $4 ];
  
  :local Scripts [$ListScriptsByCategory $Category];
  :local Buttons ({});
  
  :if ([:len $Scripts] = 0) do={
    :local NoScriptsText ("*" . $Category . " Scripts*\n\nNo scripts available in this category.");
    :set ($Buttons->[:len $Buttons]) ({
      {text="🔙 Back"; callback_data="menu:main"}
    });
    
    :local KeyboardJSON [$CreateInlineKeyboard $Buttons];
    :global TelegramTokenId;
    :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
    :local HTTPData ("chat_id=" . $ChatId . \
      "&message_id=" . $MessageId . \
      "&text=" . [$UrlEncode $NoScriptsText] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
    
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
    } else={
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
    }
    :return;
  }
  
  # Script buttons (1 per row for better readability)
  :foreach ScriptId,ScriptData in=$Scripts do={
    :local ScriptName ($ScriptData->"name");
    :local IsInstalled false;
    :if ([:len [/system script find where name=$ScriptName]] > 0) do={
      :set IsInstalled true;
    }
    
    :local ButtonText $ScriptName;
    :if ($IsInstalled = true) do={
      :set ButtonText ($ButtonText . " ✓");
    }
    
    :set ($Buttons->[:len $Buttons]) ({
      {text=$ButtonText; callback_data=("script:" . $ScriptId)}
    });
  }
  
  # Navigation buttons
  :set ($Buttons->[:len $Buttons]) ({
    {text="🔙 Back"; callback_data="menu:main"}
  });
  
  :local CategoryName $Category;
  # Use display names for categories
  :if ($Category = "monitoring") do={ :set CategoryName "Monitoring"; }
  :if ($Category = "backup") do={ :set CategoryName "Backup"; }
  :if ($Category = "utilities") do={ :set CategoryName "Utilities"; }
  :if ($Category = "parental-control") do={ :set CategoryName "Parental Control"; }
  :if ($Category = "network-management") do={ :set CategoryName "Network Management"; }
  :if ($Category = "misc") do={ :set CategoryName "Misc"; }
  :local MenuText ("*" . $CategoryName . " Scripts*\n\nSelect a script:");
  
  :local KeyboardJSON [$CreateInlineKeyboard $Buttons];
  :global TelegramTokenId;
  :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
  :local HTTPData ("chat_id=" . $ChatId . \
    "&message_id=" . $MessageId . \
    "&text=" . [$UrlEncode $MenuText] . \
    "&parse_mode=Markdown" . \
    "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
  
  :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
    /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
  } else={
    /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
  }
}

# ============================================================================
# SHOW SCRIPT INFO
# ============================================================================

:global ShowScriptInfo do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];
  :local ThreadId [ :tostr $3 ];
  :local ScriptId [ :tostr $4 ];
  
  :local ScriptData [$GetScriptInfo $ScriptId];
  :if ([:typeof $ScriptData] != "array") do={
    :return;
  }
  
  :local ScriptName ($ScriptData->"name");
  :local Description ($ScriptData->"description");
  :local Category ($ScriptData->"category");
  :local Version ($ScriptData->"version");
  :local Source ($ScriptData->"source");
  :local Deps ($ScriptData->"dependencies");
  :local IsInstalled false;
  
  :if ([:len [/system script find where name=$ScriptName]] > 0) do={
    :set IsInstalled true;
  }
  
  :local InfoText ("*" . $ScriptName . "*\n\n");
  :if ([:len $Description] > 0) do={
    :set InfoText ($InfoText . $Description . "\n\n");
  }
  :set InfoText ($InfoText . "📦 Category: " . $Category . "\n");
  :set InfoText ($InfoText . "📌 Version: " . $Version . "\n");
  :if ($IsInstalled = true) do={
    :set InfoText ($InfoText . "✅ Status: Installed\n");
  } else={
    :set InfoText ($InfoText . "❌ Status: Not Installed\n");
  }
  
  :if ([:len $Deps] > 0) do={
    :set InfoText ($InfoText . "🔗 Dependencies: " . [:join $Deps ", "] . "\n");
  }
  
  :local Buttons ({});
  :if ($IsInstalled = false) do={
    :set ($Buttons->[:len $Buttons]) ({
      {text="📥 Install"; callback_data=("install:" . $ScriptId)}
    });
  } else={
    :set ($Buttons->[:len $Buttons]) ({
      {text="🗑️ Uninstall"; callback_data=("uninstall-ask:" . $ScriptId)}
    });
  }
  :set ($Buttons->[:len $Buttons]) ({
    {text="🔙 Back"; callback_data=("cat:" . $Category)}
  });
  
  :local KeyboardJSON [$CreateInlineKeyboard $Buttons];
  :global TelegramTokenId;
  :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
  :local HTTPData ("chat_id=" . $ChatId . \
    "&message_id=" . $MessageId . \
    "&text=" . [$UrlEncode $InfoText] . \
    "&parse_mode=Markdown" . \
    "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
  
  :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
    /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
  } else={
    /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
  }
}

# ============================================================================
# HANDLE CALLBACK QUERY
# ============================================================================

:global HandleCallbackQuery do={
  :local CallbackData [ :tostr $1 ];
  :local ChatId [ :tostr $2 ];
  :local MessageId [ :tostr $3 ];
  :local ThreadId [ :tostr $4 ];
  :local CallbackQueryId [ :tostr $5 ];
  
  # Answer callback query first
  :global TelegramTokenId;
  :local AnswerUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/answerCallbackQuery");
  :local AnswerData ("callback_query_id=" . $CallbackQueryId);
  
  :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
    /tool/fetch check-certificate=no output=none http-method=post $AnswerUrl http-data=$AnswerData;
  } else={
    /tool/fetch check-certificate=yes-without-crl output=none http-method=post $AnswerUrl http-data=$AnswerData;
  }
  
  # Handle different callback types
  :if ($CallbackData ~ "^menu:") do={
    :local Action [:pick $CallbackData 5 [:len $CallbackData]];
    :if ($Action = "main") do={
      [$ShowMainMenu $ChatId $MessageId $ThreadId];
    }
    :if ($Action = "close") do={
      :local DeleteUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/deleteMessage");
      :local DeleteData ("chat_id=" . $ChatId . "&message_id=" . $MessageId);
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $DeleteUrl http-data=$DeleteData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $DeleteUrl http-data=$DeleteData;
      }
    }
    :if ($Action = "settings") do={
      # Will be handled by user-settings module
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=true;
        subject="⚡ TxMTC | Settings";
        message="Settings menu coming soon..."
      });
    }
  }
  
  :if ($CallbackData ~ "^cat:") do={
    :local Category [:pick $CallbackData 4 [:len $CallbackData]];
    [$ShowCategoryMenu $ChatId $MessageId $ThreadId $Category];
  }
  
  :if ($CallbackData ~ "^script:") do={
    :local ScriptId [:pick $CallbackData 7 [:len $CallbackData]];
    [$ShowScriptInfo $ChatId $MessageId $ThreadId $ScriptId];
  }
  
  :if ($CallbackData ~ "^install:") do={
    :local ScriptId [:pick $CallbackData 8 [:len $CallbackData]];
    :global InstallScriptFromRegistry;
    :local Result [$InstallScriptFromRegistry $ScriptId];
    :if (($Result->"success") = true) do={
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=false;
        subject="⚡ TxMTC | Install";
        message=("✅ " . ($Result->"message"))
      });
      # Refresh script info
      [$ShowScriptInfo $ChatId $MessageId $ThreadId $ScriptId];
    } else={
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=false;
        subject="⚡ TxMTC | Install";
        message=("❌ Installation failed: " . ($Result->"error"))
      });
    }
  }
  
  # Handle uninstall confirmation request (show warning)
  :if ($CallbackData ~ "^uninstall-ask:") do={
    :local ScriptId [:pick $CallbackData 14 [:len $CallbackData]];
    :local ScriptData [$GetScriptInfo $ScriptId];
    :local ScriptName "Unknown Script";
    :if ([:typeof $ScriptData] = "array") do={
      :set ScriptName ($ScriptData->"name");
    }

    # Show confirmation dialog
    :local ConfirmMsg ("*⚠️ Confirm Uninstall*

");
    :set ConfirmMsg ($ConfirmMsg . "Are you sure you want to uninstall:
");
    :set ConfirmMsg ($ConfirmMsg . "`" . $ScriptName . "`

");
    :set ConfirmMsg ($ConfirmMsg . "_This action cannot be undone._");

    :local ConfirmButtons ({{
      {text="✅ Yes, Uninstall"; callback_data=("uninstall-confirm:" . $ScriptId)}
    }; {
      {text="❌ Cancel"; callback_data=("script:" . $ScriptId)}
    }});

    :local KeyboardJSON [$CreateInlineKeyboard $ConfirmButtons];
    :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
    :local HTTPData ("chat_id=" . $ChatId . \
      "&message_id=" . $MessageId . \
      "&text=" . [$UrlEncode $ConfirmMsg] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJSON]);

    :onerror EditErr {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
      }
    } do={
      :log warning ("interactive-menu - Failed to show uninstall confirmation: " . $EditErr);
    }
  }

  # Handle uninstall confirmation (execute uninstall)
  :if ($CallbackData ~ "^uninstall-confirm:") do={
    :local ScriptId [:pick $CallbackData 18 [:len $CallbackData]];
    :global UninstallScript;
    :local Result [$UninstallScript $ScriptId];
    :if (($Result->"success") = true) do={
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=false;
        subject="⚡ TxMTC | Uninstall";
        message=("✅ " . ($Result->"message"))
      });
      # Refresh script info
      [$ShowScriptInfo $ChatId $MessageId $ThreadId $ScriptId];
    } else={
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=false;
        subject="⚡ TxMTC | Uninstall";
        message=("❌ Uninstall failed: " . ($Result->"error"))
      });
    }
  }
  
  # Handle installer callbacks
  :if ($CallbackData ~ "^installer:") do={
    :global InteractiveInstallerLoaded;
    :if ($InteractiveInstallerLoaded != true) do={
      :onerror e { /system script run "modules/interactive-installer"; } do={}
    }
    :global HandleInstallerCallback;
    :global EditTelegramMessage;
    :global CreateInlineKeyboard;
    
    :local Result [$HandleInstallerCallback $CallbackData $MessageId];
    :if ([:typeof $Result] = "array") do={
      :local MsgText ($Result->"message");
      :local Keyboard ($Result->"keyboard");
      :local KeyboardJson [$CreateInlineKeyboard $Keyboard];
      [$EditTelegramMessage $ChatId $MessageId $MsgText $KeyboardJson];
    }
  }

  # Handle monitoring settings toggles
  :if ($CallbackData ~ "^monitoring-settings:toggle:") do={
    :local Toggle [:pick $CallbackData 27 [:len $CallbackData]];
    :global MonitorCPUEnabled;
    :global MonitorRAMEnabled;
    :global MonitorDiskEnabled;
    :global MonitorInterfacesEnabled;
    :global MonitorInternetEnabled;

    :if ($Toggle = "cpu") do={ :set MonitorCPUEnabled (!$MonitorCPUEnabled); }
    :if ($Toggle = "ram") do={ :set MonitorRAMEnabled (!$MonitorRAMEnabled); }
    :if ($Toggle = "disk") do={ :set MonitorDiskEnabled (!$MonitorDiskEnabled); }
    :if ($Toggle = "interfaces") do={ :set MonitorInterfacesEnabled (!$MonitorInterfacesEnabled); }
    :if ($Toggle = "internet") do={ :set MonitorInternetEnabled (!$MonitorInternetEnabled); }

    # Refresh the settings menu to show updated state
    [$ShowMonitoringSettings $ChatId $MessageId $ThreadId];
  }
}

# ============================================================================
# SHOW MONITORING SETTINGS MENU
# ============================================================================

:global ShowMonitoringSettings do={
  :local ChatId [ :tostr $1 ];
  :local MessageId [ :tostr $2 ];
  :local ThreadId [ :tostr $3 ];
  
  :global MonitorCPUEnabled;
  :global MonitorRAMEnabled;
  :global MonitorDiskEnabled;
  :global MonitorInterfacesEnabled;
  :global MonitorInternetEnabled;
  :global MonitorTempEnabled;
  :global MonitorVoltageEnabled;
  :global MonitorInterfaces;
  :global MonitorCPUThreshold;
  :global MonitorRAMThreshold;
  :global MonitorDiskThreshold;
  
  :if ([:typeof $MonitorCPUEnabled] != "bool") do={ :set MonitorCPUEnabled true; }
  :if ([:typeof $MonitorRAMEnabled] != "bool") do={ :set MonitorRAMEnabled true; }
  :if ([:typeof $MonitorDiskEnabled] != "bool") do={ :set MonitorDiskEnabled true; }
  :if ([:typeof $MonitorInterfacesEnabled] != "bool") do={ :set MonitorInterfacesEnabled true; }
  :if ([:typeof $MonitorInternetEnabled] != "bool") do={ :set MonitorInternetEnabled true; }
  :if ([:typeof $MonitorTempEnabled] != "bool") do={ :set MonitorTempEnabled true; }
  :if ([:typeof $MonitorVoltageEnabled] != "bool") do={ :set MonitorVoltageEnabled true; }
  
  :local icons {false="❌"; true="✅"};
  :local SettingsMsg ("⚙️ *Monitoring Settings*\n\n");
  :set SettingsMsg ($SettingsMsg . "📊 *Enabled Monitoring:*\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorCPUEnabled]) . " CPU\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorRAMEnabled]) . " RAM\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorDiskEnabled]) . " Disk\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorInterfacesEnabled]) . " Interfaces\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorInternetEnabled]) . " Internet\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorTempEnabled]) . " Temperature\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $MonitorVoltageEnabled]) . " Voltage\n\n");
  :set SettingsMsg ($SettingsMsg . "📈 *Thresholds:*\n");
  :set SettingsMsg ($SettingsMsg . "CPU: " . $MonitorCPUThreshold . "%\n");
  :set SettingsMsg ($SettingsMsg . "RAM: " . $MonitorRAMThreshold . "%\n");
  :set SettingsMsg ($SettingsMsg . "Disk: " . $MonitorDiskThreshold . "%\n\n");
  :set SettingsMsg ($SettingsMsg . "🔌 *Interfaces:*\n`" . $MonitorInterfaces . "`\n\n");
  :set SettingsMsg ($SettingsMsg . "Use `/monitor-interfaces` to configure\\.");
  
  :local Buttons ({{
    {text="Toggle CPU"; callback_data="monitoring-settings:toggle:cpu"};
    {text="Toggle RAM"; callback_data="monitoring-settings:toggle:ram"}
  }; {
    {text="Toggle Disk"; callback_data="monitoring-settings:toggle:disk"};
    {text="Toggle Interfaces"; callback_data="monitoring-settings:toggle:interfaces"}
  }; {
    {text="Toggle Internet"; callback_data="monitoring-settings:toggle:internet"};
    {text="🔌 Interfaces"; callback_data="cmd:/monitor-interfaces list"}
  }; {
    {text="🔙 Back"; callback_data="menu:main"}
  }});

  :local KeyboardJson [$CreateInlineKeyboard $Buttons];
  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;

  :if ([:len $MessageId] > 0 && $MessageId != "0" && $MessageId != "") do={
    # Edit existing message
    :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
    :local HTTPData ("chat_id=" . $ChatId . \
      "&message_id=" . $MessageId . \
      "&text=" . [$UrlEncode $SettingsMsg] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJson]);

    :onerror EditErr {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
      }
    } do={
      :log warning ("ShowMonitoringSettings - Failed to edit message: " . $EditErr);
    }
  } else={
    # Send new message
    [$SendTelegramWithKeyboard $ChatId $SettingsMsg $KeyboardJson $ThreadId];
  }
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global InteractiveMenuLoaded true;
:log info "Interactive menu module loaded"
