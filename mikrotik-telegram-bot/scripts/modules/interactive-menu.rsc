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

  # Build JSON manually (RouterOS :serialize has bugs with nested arrays)
  :local Json "{\"inline_keyboard\":[";
  :local IsFirstRow true;
  # Key names as variables (RouterOS bug: -> accessor fails with underscore keys)
  :local KeyText "text";
  :local KeyData "callback_data";

  :foreach Row in=$Buttons do={
    :if ($IsFirstRow = false) do={ :set Json ($Json . ","); }
    :set IsFirstRow false;
    :set Json ($Json . "[");

    :local IsFirstBtn true;
    :foreach Button in=$Row do={
      :if ($IsFirstBtn = false) do={ :set Json ($Json . ","); }
      :set IsFirstBtn false;

      :local BtnText ($Button->$KeyText);
      :local BtnData ($Button->$KeyData);
      :set Json ($Json . "{\"text\":\"" . $BtnText . "\",\"callback_data\":\"" . $BtnData . "\"}");
    }
    :set Json ($Json . "]");
  }

  :set Json ($Json . "]}");
  :return $Json;
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
  :local SendData ("chat_id=" . $ChatId . "&text=" . [$UrlEncode $MessageText] . "&parse_mode=Markdown" . "&reply_markup=" . [$UrlEncode $KeyboardJSON]);
  
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
        :set ($Row->[:len $Row]) ({"text"=$Cmd; "callback_data"=("cmd:" . $Cmd)});
        :set Count ($Count + 1);
        :if ($Count = 2) do={
          :set ($Result->[:len $Result]) $Row;
          :set Row ({});
          :set Count 0;
        }
      }
    } else={
      # Single command string
      :set ($Row->[:len $Row]) ({"text"=$CmdOrArray; "callback_data"=("cmd:" . $CmdOrArray)});
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
      "text"=($Emoji . " " . $CatName);
      "callback_data"=("cat:" . $Cat)
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
    {"text"="📥 Install Script"; "callback_data"="menu:install"};
    {"text"="🔍 Search"; "callback_data"="menu:search"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="🌐 Hotspot"; "callback_data"="menu:hotspot"};
    {"text"="🌉 Bridge/VLAN"; "callback_data"="menu:bridge"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="⚙️ Settings"; "callback_data"="menu:settings"};
    {"text"="📊 Monitoring"; "callback_data"="cmd:/monitoring-settings"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="🤖 Error Monitor"; "callback_data"="menu:error-monitor"};
    {"text"="🛠️ Setup"; "callback_data"="menu:setup"}
  });
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="🌐 Routers"; "callback_data"="menu:routers"};
    {"text"="❌ Close"; "callback_data"="menu:close"}
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
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];
  :local Category [:tostr $4];
  :local Page [:tonum $5];

  # Default to page 1
  :if ($Page < 1) do={ :set Page 1; }

  :local ItemsPerPage 8;
  :local Scripts [$ListScriptsByCategory $Category];
  :local TotalScripts [:len $Scripts];
  :local TotalPages (($TotalScripts + $ItemsPerPage - 1) / $ItemsPerPage);
  :if ($TotalPages < 1) do={ :set TotalPages 1; }
  :if ($Page > $TotalPages) do={ :set Page $TotalPages; }

  :local Buttons ({});

  :if ($TotalScripts = 0) do={
    :local NoScriptsText ("*" . $Category . " Scripts*\n\nNo scripts available in this category.");
    :set ($Buttons->[:len $Buttons]) ({
      {"text"="🔙 Back"; "callback_data"="menu:main"}
    });

    :local KeyboardJSON [$CreateInlineKeyboard $Buttons];
    :global TelegramTokenId;
    :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
    :local HTTPData ("chat_id=" . $ChatId . \
      "&message_id=" . $MessageId . \
      "&text=" . [$UrlEncode $NoScriptsText] . \
      "&parse_mode=Markdown" . \
      "&reply_markup=" . [$UrlEncode $KeyboardJSON]);

    :onerror Err {
      :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
        /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
      } else={
        /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
      }
    } do={}
    :return;
  }

  # Calculate pagination range
  :local StartIdx (($Page - 1) * $ItemsPerPage);
  :local EndIdx ($StartIdx + $ItemsPerPage);
  :if ($EndIdx > $TotalScripts) do={ :set EndIdx $TotalScripts; }

  # Script buttons (1 per row for better readability)
  :local Idx 0;
  :foreach ScriptId,ScriptData in=$Scripts do={
    :if ($Idx >= $StartIdx && $Idx < $EndIdx) do={
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
        {"text"=$ButtonText; "callback_data"=("script:" . $ScriptId)}
      });
    }
    :set Idx ($Idx + 1);
  }

  # Pagination buttons (if needed)
  :if ($TotalPages > 1) do={
    :local PageButtons ({});
    :if ($Page > 1) do={
      :set ($PageButtons->[:len $PageButtons]) {
        "text"="◀️ Prev";
        "callback_data"=("catpage:" . $Category . ":" . ($Page - 1))
      };
    }
    :set ($PageButtons->[:len $PageButtons]) {
      "text"=([:tostr $Page] . "/" . [:tostr $TotalPages]);
      "callback_data"="noop"
    };
    :if ($Page < $TotalPages) do={
      :set ($PageButtons->[:len $PageButtons]) {
        "text"="Next ▶️";
        "callback_data"=("catpage:" . $Category . ":" . ($Page + 1))
      };
    }
    :set ($Buttons->[:len $Buttons]) $PageButtons;
  }

  # Navigation buttons
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="🔙 Back"; "callback_data"="menu:main"}
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

  :onerror Err {
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
    } else={
      /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
    }
  } do={}
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
      {"text"="📥 Install"; "callback_data"=("install:" . $ScriptId)}
    });
  } else={
    :set ($Buttons->[:len $Buttons]) ({
      {"text"="🗑️ Uninstall"; "callback_data"=("uninstall-ask:" . $ScriptId)}
    });
  }
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="🔙 Back"; "callback_data"=("cat:" . $Category)}
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
      :global ShowUserSettings;
      [$ShowUserSettings $ChatId $MessageId $ThreadId];
    }
    :if ($Action = "error-monitor") do={
      [$ShowErrorMonitorSettings $ChatId $MessageId $ThreadId];
    }
    :if ($Action = "install") do={
      :global ShowInstallerMainMenu;
      :if ([:typeof $ShowInstallerMainMenu] = "nothing") do={
        :onerror LoadErr {
          /system script run "modules/interactive-installer";
        } do={
          :log warning ("interactive-menu - Could not load installer module");
        }
      }
      :if ([:typeof $ShowInstallerMainMenu] != "nothing") do={
        [$ShowInstallerMainMenu $ChatId $MessageId $ThreadId];
      } else={
        $SendTelegram2 ({
          chatid=$ChatId;
          threadid=$ThreadId;
          silent=true;
          subject="⚡ TxMTC | Install";
          message="❌ Installer module not available"
        });
      }
    }
    :if ($Action = "search") do={
      :local SearchMsg "*🔍 Search Scripts*\n\n";
      :set SearchMsg ($SearchMsg . "Use inline mode to search:\n\n");
      :set SearchMsg ($SearchMsg . "Type `@YourBotName query` in any chat\n\n");
      :set SearchMsg ($SearchMsg . "_Example: @TxMTC\\_bot backup_");

      :local Buttons ({{
        {"text"="🔙 Back"; "callback_data"="menu:main"}
      }});
      :local KeyboardJson [$CreateInlineKeyboard $Buttons];

      :local EditUrl ("https://api.telegram.org/bot" . $TelegramTokenId . "/editMessageText");
      :local HTTPData ("chat_id=" . $ChatId . \
        "&message_id=" . $MessageId . \
        "&text=" . [$UrlEncode $SearchMsg] . \
        "&parse_mode=Markdown" . \
        "&reply_markup=" . [$UrlEncode $KeyboardJson]);

      :onerror EditErr {
        :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
          /tool/fetch check-certificate=no output=none http-method=post $EditUrl http-data=$HTTPData;
        } else={
          /tool/fetch check-certificate=yes-without-crl output=none http-method=post $EditUrl http-data=$HTTPData;
        }
      } do={
        :log warning ("interactive-menu - Failed to show search hint: " . $EditErr);
      }
    }
  }
  
  :if ($CallbackData ~ "^cat:") do={
    :local Category [:pick $CallbackData 4 [:len $CallbackData]];
    [$ShowCategoryMenu $ChatId $MessageId $ThreadId $Category 1];
  }

  # Handle category pagination
  :if ($CallbackData ~ "^catpage:") do={
    :global ParseCallbackParts;
    :local Parts [$ParseCallbackParts $CallbackData ":"];
    # Parts: catpage, category, page
    :if ([:len $Parts] >= 3) do={
      :local Category ($Parts->1);
      :local Page [:tonum ($Parts->2)];
      [$ShowCategoryMenu $ChatId $MessageId $ThreadId $Category $Page];
    }
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
      {"text"="✅ Yes, Uninstall"; "callback_data"=("uninstall-confirm:" . $ScriptId)}
    }; {
      {"text"="❌ Cancel"; "callback_data"=("script:" . $ScriptId)}
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

  # Handle error monitor toggles
  :if ($CallbackData ~ "^error-monitor:") do={
    :local Action [:pick $CallbackData 14 [:len $CallbackData]];
    :global ErrorMonitorEnabled;
    :global ErrorMonitorAutoFix;
    :global StartErrorMonitor;
    :global StopErrorMonitor;
    :global RunErrorMonitor;

    :if ($Action = "toggle") do={
      :if ($ErrorMonitorEnabled = true) do={
        [$StopErrorMonitor];
      } else={
        [$StartErrorMonitor];
      }
    }
    :if ($Action = "autofix") do={
      :set ErrorMonitorAutoFix (!$ErrorMonitorAutoFix);
    }
    :if ($Action = "scan") do={
      [$RunErrorMonitor];
      $SendTelegram2 ({
        chatid=$ChatId;
        threadid=$ThreadId;
        silent=true;
        subject="⚡ TxMTC | Error Monitor";
        message="🔍 Manual error scan triggered..."
      });
    }

    # Refresh the error monitor menu
    [$ShowErrorMonitorSettings $ChatId $MessageId $ThreadId];
  }

  # Handle user settings toggles
  :if ($CallbackData ~ "^settings:toggle:") do={
    :local Toggle [:pick $CallbackData 16 [:len $CallbackData]];
    :global NotificationSilent;
    :global SendDailySummary;
    :global AutoCleanupEnabled;
    :global EnableAutoMonitoring;
    :global ShowUserSettings;

    :if ($Toggle = "notifications") do={ :set NotificationSilent (!$NotificationSilent); }
    :if ($Toggle = "summary") do={ :set SendDailySummary (!$SendDailySummary); }
    :if ($Toggle = "cleanup") do={ :set AutoCleanupEnabled (!$AutoCleanupEnabled); }
    :if ($Toggle = "monitoring") do={ :set EnableAutoMonitoring (!$EnableAutoMonitoring); }

    # Refresh the settings menu
    [$ShowUserSettings $ChatId $MessageId $ThreadId];
  }

  # Handle hotspot callbacks
  :if ($CallbackData ~ "^hotspot:") do={
    :global HotspotMonitorLoaded;
    :if ($HotspotMonitorLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/hotspot-monitor";
      } do={
        :log warning "[interactive-menu] - Could not load hotspot-monitor module";
      }
    }
    :global HandleHotspotCallback;
    :if ([:typeof $HandleHotspotCallback] = "array") do={
      [$HandleHotspotCallback $ChatId $MessageId $CallbackData $ThreadId];
    }
  }

  # Handle bridge callbacks
  :if ($CallbackData ~ "^bridge:") do={
    :global BridgeVlanLoaded;
    :if ($BridgeVlanLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/bridge-vlan";
      } do={
        :log warning "[interactive-menu] - Could not load bridge-vlan module";
      }
    }
    :global HandleBridgeCallback;
    :if ([:typeof $HandleBridgeCallback] = "array") do={
      [$HandleBridgeCallback $ChatId $MessageId $CallbackData $ThreadId];
    }
  }

  # Handle setup wizard callbacks
  :if ($CallbackData ~ "^setup:") do={
    :global SetupWizardLoaded;
    :if ($SetupWizardLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/setup-wizard";
      } do={
        :log warning "[interactive-menu] - Could not load setup-wizard module";
      }
    }
    :global HandleSetupCallback;
    :if ([:typeof $HandleSetupCallback] = "array") do={
      [$HandleSetupCallback $ChatId $MessageId $CallbackData $ThreadId];
    }
  }

  # Handle router callbacks
  :if ($CallbackData ~ "^router:") do={
    :global MultiRouterLoaded;
    :if ($MultiRouterLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/multi-router";
      } do={
        :log warning "[interactive-menu] - Could not load multi-router module";
      }
    }
    :global HandleRouterCallback;
    :if ([:typeof $HandleRouterCallback] = "array") do={
      # Parse callback: router:action:param
      :local Parts [:toarray ""];
      :local TmpData [:pick $CallbackData 7 [:len $CallbackData]];
      :local ColonPos [:find $TmpData ":"];
      :local Action $TmpData;
      :local Param "";
      :if ([:typeof $ColonPos] = "num") do={
        :set Action [:pick $TmpData 0 $ColonPos];
        :set Param [:pick $TmpData ($ColonPos + 1) [:len $TmpData]];
      }
      [$HandleRouterCallback $Action $Param $CallbackId];
    }
  }

  # Handle menu:hotspot, menu:bridge, menu:setup
  :if ($CallbackData = "menu:hotspot") do={
    :global HotspotMonitorLoaded;
    :if ($HotspotMonitorLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/hotspot-monitor";
      } do={
        :log warning "[interactive-menu] - Could not load hotspot-monitor module";
      }
    }
    :global ShowHotspotMenu;
    :if ([:typeof $ShowHotspotMenu] = "array") do={
      [$ShowHotspotMenu $ChatId $MessageId $ThreadId];
    }
  }

  :if ($CallbackData = "menu:bridge") do={
    :global BridgeVlanLoaded;
    :if ($BridgeVlanLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/bridge-vlan";
      } do={
        :log warning "[interactive-menu] - Could not load bridge-vlan module";
      }
    }
    :global ShowBridgeMenu;
    :if ([:typeof $ShowBridgeMenu] = "array") do={
      [$ShowBridgeMenu $ChatId $MessageId $ThreadId];
    }
  }

  :if ($CallbackData = "menu:setup") do={
    :global SetupWizardLoaded;
    :if ($SetupWizardLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/setup-wizard";
      } do={
        :log warning "[interactive-menu] - Could not load setup-wizard module";
      }
    }
    :global ShowSetupWizard;
    :if ([:typeof $ShowSetupWizard] = "array") do={
      [$ShowSetupWizard $ChatId $MessageId $ThreadId];
    }
  }

  :if ($CallbackData = "menu:routers") do={
    :global MultiRouterLoaded;
    :if ($MultiRouterLoaded != true) do={
      :onerror LoadErr {
        /system script run "modules/multi-router";
      } do={
        :log warning "[interactive-menu] - Could not load multi-router module";
      }
    }
    :global ShowRoutersMenu;
    :if ([:typeof $ShowRoutersMenu] = "array") do={
      [$ShowRoutersMenu];
    }
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
    {"text"="Toggle CPU"; "callback_data"="monitoring-settings:toggle:cpu"};
    {"text"="Toggle RAM"; "callback_data"="monitoring-settings:toggle:ram"}
  }; {
    {"text"="Toggle Disk"; "callback_data"="monitoring-settings:toggle:disk"};
    {"text"="Toggle Interfaces"; "callback_data"="monitoring-settings:toggle:interfaces"}
  }; {
    {"text"="Toggle Internet"; "callback_data"="monitoring-settings:toggle:internet"};
    {"text"="🔌 Interfaces"; "callback_data"="cmd:/monitor-interfaces list"}
  }; {
    {"text"="🔙 Back"; "callback_data"="menu:main"}
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
# SHOW ERROR MONITOR SETTINGS MENU
# ============================================================================

:global ShowErrorMonitorSettings do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];

  :global ErrorMonitorEnabled;
  :global ErrorMonitorAutoFix;
  :global ErrorMonitorInterval;
  :global ErrorMonitorProcessedErrors;
  :global ErrorMonitorFixHistory;
  :global ClaudeRelayNativeEnabled;
  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;

  # Initialize if not set
  :if ([:typeof $ErrorMonitorEnabled] != "bool") do={ :set ErrorMonitorEnabled false; }
  :if ([:typeof $ErrorMonitorAutoFix] != "bool") do={ :set ErrorMonitorAutoFix false; }
  :if ([:typeof $ErrorMonitorInterval] != "time") do={ :set ErrorMonitorInterval 00:01:00; }
  :if ([:typeof $ErrorMonitorProcessedErrors] != "array") do={ :set ErrorMonitorProcessedErrors ({}); }
  :if ([:typeof $ErrorMonitorFixHistory] != "array") do={ :set ErrorMonitorFixHistory ({}); }

  :local ProcessedCount [:len $ErrorMonitorProcessedErrors];
  :local FixCount [:len $ErrorMonitorFixHistory];
  :local ClaudeStatus "❌ Not Available";
  :if ($ClaudeRelayNativeEnabled = true) do={ :set ClaudeStatus "✅ Ready"; }

  :local icons {false="❌"; true="✅"};
  :local StatusIcon ($icons->[:tostr $ErrorMonitorEnabled]);
  :local AutoFixIcon ($icons->[:tostr $ErrorMonitorAutoFix]);

  :local SettingsMsg ("🤖 *Error Monitor Settings*\n\n");
  :set SettingsMsg ($SettingsMsg . "*Status:* " . $StatusIcon . "\n");
  :set SettingsMsg ($SettingsMsg . "*Auto-Fix:* " . $AutoFixIcon . "\n");
  :set SettingsMsg ($SettingsMsg . "*Interval:* " . [:tostr $ErrorMonitorInterval] . "\n\n");
  :set SettingsMsg ($SettingsMsg . "*Claude AI:* " . $ClaudeStatus . "\n\n");
  :set SettingsMsg ($SettingsMsg . "📊 *Statistics:*\n");
  :set SettingsMsg ($SettingsMsg . "Errors Processed: " . $ProcessedCount . "\n");
  :set SettingsMsg ($SettingsMsg . "Fixes Applied: " . $FixCount . "\n\n");
  :set SettingsMsg ($SettingsMsg . "_When enabled, system logs are scanned for errors and analyzed by Claude AI._");

  :local ToggleText "▶️ Enable";
  :if ($ErrorMonitorEnabled = true) do={ :set ToggleText "⏹️ Disable"; }

  :local AutoFixText "Enable Auto-Fix";
  :if ($ErrorMonitorAutoFix = true) do={ :set AutoFixText "Disable Auto-Fix"; }

  :local Buttons ({{
    {"text"=$ToggleText; "callback_data"="error-monitor:toggle"}
  }; {
    {"text"=$AutoFixText; "callback_data"="error-monitor:autofix"};
    {"text"="🔍 Scan Now"; "callback_data"="error-monitor:scan"}
  }; {
    {"text"="🔙 Back"; "callback_data"="menu:main"}
  }});

  :local KeyboardJson [$CreateInlineKeyboard $Buttons];

  :if ([:len $MessageId] > 0 && $MessageId != "0" && $MessageId != "") do={
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
      :log warning ("ShowErrorMonitorSettings - Failed to edit: " . $EditErr);
    }
  } else={
    [$SendTelegramWithKeyboard $ChatId $SettingsMsg $KeyboardJson $ThreadId];
  }
}

# ============================================================================
# SHOW USER SETTINGS MENU
# ============================================================================

:global ShowUserSettings do={
  :local ChatId [:tostr $1];
  :local MessageId [:tostr $2];
  :local ThreadId [:tostr $3];

  :global NotificationSilent;
  :global SendDailySummary;
  :global AutoCleanupEnabled;
  :global EnableAutoMonitoring;
  :global TelegramTokenId;
  :global UrlEncode;
  :global CertificateAvailable;
  :global CreateInlineKeyboard;
  :global SendTelegramWithKeyboard;

  # Initialize defaults if not set
  :if ([:typeof $NotificationSilent] != "bool") do={ :set NotificationSilent false; }
  :if ([:typeof $SendDailySummary] != "bool") do={ :set SendDailySummary true; }
  :if ([:typeof $AutoCleanupEnabled] != "bool") do={ :set AutoCleanupEnabled true; }
  :if ([:typeof $EnableAutoMonitoring] != "bool") do={ :set EnableAutoMonitoring true; }

  :local icons {false="❌"; true="✅"};

  :local SettingsMsg ("⚙️ *User Settings*\n\n");
  :set SettingsMsg ($SettingsMsg . "*Notifications:*\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr (!$NotificationSilent)]) . " Sound alerts\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $SendDailySummary]) . " Daily summary\n\n");
  :set SettingsMsg ($SettingsMsg . "*Automation:*\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $AutoCleanupEnabled]) . " Auto cleanup\n");
  :set SettingsMsg ($SettingsMsg . ($icons->[:tostr $EnableAutoMonitoring]) . " Auto monitoring\n\n");
  :set SettingsMsg ($SettingsMsg . "_Tap buttons below to toggle settings._");

  :local Buttons ({{
    {"text"="🔔 Notifications"; "callback_data"="settings:toggle:notifications"};
    {"text"="📊 Daily Summary"; "callback_data"="settings:toggle:summary"}
  }; {
    {"text"="🧹 Auto Cleanup"; "callback_data"="settings:toggle:cleanup"};
    {"text"="📈 Auto Monitor"; "callback_data"="settings:toggle:monitoring"}
  }; {
    {"text"="🔙 Back"; "callback_data"="menu:main"}
  }});

  :local KeyboardJson [$CreateInlineKeyboard $Buttons];

  :if ([:len $MessageId] > 0 && $MessageId != "0" && $MessageId != "") do={
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
      :log warning ("ShowUserSettings - Failed to edit: " . $EditErr);
    }
  } else={
    [$SendTelegramWithKeyboard $ChatId $SettingsMsg $KeyboardJson $ThreadId];
  }
}

# ============================================================================
# GET QUICK ACTIONS FOR CONTEXT
# ============================================================================
# Returns context-aware quick action buttons based on message type

:global GetQuickActionsForContext do={
  :local Context [:tostr $1];
  :local Buttons ({});

  # Status/System context
  :if ($Context = "status" || $Context = "system") do={
    :set ($Buttons->0) ({
      {"text"="🔄 Refresh"; "callback_data"="cmd:/status"};
      {"text"="📶 Interfaces"; "callback_data"="cmd:/interfaces"}
    });
    :set ($Buttons->1) ({
      {"text"="📋 DHCP"; "callback_data"="cmd:/dhcp"};
      {"text"="📊 Resources"; "callback_data"="cmd:/system resource print"}
    });
  }

  # Hotspot context
  :if ($Context = "hotspot") do={
    :set ($Buttons->0) ({
      {"text"="👥 Users"; "callback_data"="hotspot:users"};
      {"text"="➕ Add User"; "callback_data"="hotspot:add"}
    });
    :set ($Buttons->1) ({
      {"text"="➖ Remove"; "callback_data"="hotspot:remove"};
      {"text"="📊 Stats"; "callback_data"="hotspot:stats"}
    });
  }

  # Monitoring context
  :if ($Context = "monitoring" || $Context = "alert") do={
    :set ($Buttons->0) ({
      {"text"="⚙️ Settings"; "callback_data"="cmd:/monitoring-settings"};
      {"text"="🔇 Silence 1h"; "callback_data"="cmd:/silence 1h"}
    });
    :set ($Buttons->1) ({
      {"text"="📊 Status"; "callback_data"="cmd:/status"};
      {"text"="📋 Logs"; "callback_data"="cmd:/log print count=10"}
    });
  }

  # Network context
  :if ($Context = "network" || $Context = "interfaces") do={
    :set ($Buttons->0) ({
      {"text"="📶 Interfaces"; "callback_data"="cmd:/interface print stats"};
      {"text"="🛣️ Routes"; "callback_data"="cmd:/ip route print"}
    });
    :set ($Buttons->1) ({
      {"text"="🔥 Firewall"; "callback_data"="cmd:/ip firewall filter print stats"};
      {"text"="📋 ARP"; "callback_data"="cmd:/ip arp print"}
    });
  }

  # Backup context
  :if ($Context = "backup") do={
    :set ($Buttons->0) ({
      {"text"="💾 Create Backup"; "callback_data"="cmd:/backup now"};
      {"text"="📤 Export"; "callback_data"="cmd:/export file=manual-export"}
    });
  }

  # Error/Log context
  :if ($Context = "error" || $Context = "logs") do={
    :set ($Buttons->0) ({
      {"text"="📋 Recent Logs"; "callback_data"="cmd:/log print count=20"};
      {"text"="⚠️ Errors Only"; "callback_data"="cmd:/errors"}
    });
    :set ($Buttons->1) ({
      {"text"="🧹 Clear Logs"; "callback_data"="cmd:/system logging action set memory memory-lines=1"};
      {"text"="🔄 Refresh"; "callback_data"="cmd:/log print count=10"}
    });
  }

  # Default/General context (always add navigation row)
  :if ([:len $Buttons] = 0) do={
    :set ($Buttons->0) ({
      {"text"="📊 Status"; "callback_data"="cmd:/status"};
      {"text"="📶 Interfaces"; "callback_data"="cmd:/interfaces"}
    });
  }

  # Add navigation row at the end
  :set ($Buttons->[:len $Buttons]) ({
    {"text"="📋 Menu"; "callback_data"="menu:main"};
    {"text"="🖥️ Routers"; "callback_data"="menu:routers"}
  });

  :return $Buttons;
}

# ============================================================================
# GET CONTEXT FROM MESSAGE CONTENT
# ============================================================================
# Analyzes message text to determine context for quick actions

:global DetectMessageContext do={
  :local MessageText [:tostr $1];
  :local LowerText $MessageText;

  # Try to detect context from keywords
  :if ($MessageText ~ "(?i)(hotspot|user|voucher)") do={ :return "hotspot"; }
  :if ($MessageText ~ "(?i)(cpu|ram|memory|disk|uptime|resource)") do={ :return "status"; }
  :if ($MessageText ~ "(?i)(interface|ether|bridge|wlan|vlan)") do={ :return "network"; }
  :if ($MessageText ~ "(?i)(backup|export|restore)") do={ :return "backup"; }
  :if ($MessageText ~ "(?i)(error|warning|critical|failed)") do={ :return "error"; }
  :if ($MessageText ~ "(?i)(monitor|alert|threshold)") do={ :return "monitoring"; }
  :if ($MessageText ~ "(?i)(log|event|message)") do={ :return "logs"; }

  :return "general";
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global InteractiveMenuLoaded true;
:log info "Interactive menu module loaded"
