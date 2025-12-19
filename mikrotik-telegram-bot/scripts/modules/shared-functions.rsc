#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Shared Functions Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Core helper functions used across all modules
# This module exports global functions - import before using other modules

# ============================================================================
# URL ENCODING
# ============================================================================

:global UrlEncode do={
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
          :if ($Char = "\r") do={
            :set Result ($Result . "%0D");
          } else={
            :if ($Char = "\t") do={
              :set Result ($Result . "%09");
            } else={
              :local CharArray [:toarray $Char];
              :local FirstChar ($CharArray->0);
              :local CharCode [:tonum $FirstChar];
              :if ([:typeof $CharCode] = "num" && $CharCode >= 0 && $CharCode <= 255) do={
                :local Hex1 [:pick "0123456789ABCDEF" ($CharCode / 16) ($CharCode / 16 + 1)];
                :local Hex2 [:pick "0123456789ABCDEF" ($CharCode % 16) ($CharCode % 16 + 1)];
                :set Result ($Result . ("%" . $Hex1 . $Hex2));
              } else={
                :set Result ($Result . $Char);
              }
            }
          }
        }
      }
    }
  }
  :return $Result;
}

# ============================================================================
# CHARACTER REPLACE
# ============================================================================

:global CharacterReplace do={
  :local String [ :tostr $1 ];
  :local Find [ :tostr $2 ];
  :local Replace [ :tostr $3 ];
  :if ([:len $Find] = 0) do={
    :return $String;
  }
  :local Result "";
  :local Pos 0;
  
  :while ([:len $String] > 0) do={
    :local NextPos [:find $String $Find $Pos];
    :if ([:typeof $NextPos] = "nil") do={
      :set Result ($Result . [:pick $String $Pos [:len $String]]);
      :set String "";
    } else={
      :set Result ($Result . [:pick $String $Pos $NextPos] . $Replace);
      :set Pos ($NextPos + [:len $Find]);
    }
  }
  :return $Result;
}

# ============================================================================
# ESCAPE MARKDOWN V2
# ============================================================================

:global EscapeMD do={
  :local Text [ :tostr $1 ];
  :local Mode [ :tostr $2 ];
  :global CharacterReplace;

  :local Chars ({ "\\"; "`"; "_"; "*"; "["; "]"; "("; ")"; "~"; ">"; "#"; "+"; "-"; "="; "|"; "{"; "}"; "."; "!" });
  :if ($Mode = "body") do={
    :set Chars ({ "\\"; "`" });
  }
  
  :foreach Char in=$Chars do={
    :set Text [$CharacterReplace $Text $Char ("\\" . $Char)];
  }
  
  :if ($Mode = "body") do={
    :return ("```\n" . $Text . "\n```");
  }
  :return $Text;
}

# ============================================================================
# FORMAT BYTES (Human Readable)
# ============================================================================

:global FormatBytes do={
  :local Bytes [:tonum $1];
  :local Units ({"B"; "KB"; "MB"; "GB"; "TB"});
  :local UnitIndex 0;
  
  :while ($Bytes >= 1024 && $UnitIndex < 4) do={
    :set Bytes ($Bytes / 1024);
    :set UnitIndex ($UnitIndex + 1);
  }
  
  :return ([:tostr $Bytes] . ($Units->$UnitIndex));
}

# ============================================================================
# FORMAT NUMBER (Human Readable with Divisor)
# ============================================================================

:global FormatNumber do={
  :local Num [:tonum $1];
  :local Div [:tonum $2];
  :local Units ({""; "K"; "M"; "G"; "T"});
  :local UnitIndex 0;
  
  :if ([:typeof $Div] != "num" || $Div = 0) do={
    :set Div 1000;
  }
  
  :while ($Num >= $Div && $UnitIndex < 4) do={
    :set Num ($Num / $Div);
    :set UnitIndex ($UnitIndex + 1);
  }
  
  :return ([:tostr $Num] . ($Units->$UnitIndex));
}

# ============================================================================
# CERTIFICATE CHECK
# ============================================================================

:global CertificateAvailable do={
  :local CommonName [ :tostr $1 ];
  :if ([:len $CommonName] = 0) do={
    :set CommonName "ISRG Root X1";
  }
  :if ([ :len [ /certificate find where common-name=$CommonName ] ] > 0) do={
    :return true;
  }
  :return false;
}

# ============================================================================
# VALIDATE SYNTAX
# ============================================================================

:global ValidateSyntax do={
  :local Code [ :tostr $1 ];
  :onerror SyntaxErr {
    :parse $Code;
    :return true;
  } do={
    :return false;
  }
}

# ============================================================================
# STATE PERSISTENCE - SAVE
# ============================================================================

:global SaveBotState do={
  :local StateName [ :tostr $1 ];
  :local StateData $2;
  :local StateFile ("tmpfs/bot-state-" . $StateName . ".txt");
  
  :onerror SaveErr {
    :local JSON [ :serialize to=json value=$StateData ];
    /file/add name=$StateFile contents=$JSON;
    :log debug ("shared-functions - Saved state: " . $StateName);
    :return true;
  } do={
    :log warning ("shared-functions - Failed to save state " . $StateName . ": " . $SaveErr);
    :return false;
  }
}

# ============================================================================
# STATE PERSISTENCE - LOAD
# ============================================================================

:global LoadBotState do={
  :local StateName [ :tostr $1 ];
  :local StateFile ("tmpfs/bot-state-" . $StateName . ".txt");
  
  :onerror LoadErr {
    :if ([:len [/file find name=$StateFile]] > 0) do={
      :local StateData ([/file get $StateFile contents]);
      :if ([:len $StateData] > 0) do={
        :local Result [ :deserialize from=json $StateData ];
        :log debug ("shared-functions - Loaded state: " . $StateName);
        :return $Result;
      }
    }
  } do={
    :log debug ("shared-functions - State file not found: " . $StateName);
  }
  :return;
}

# ============================================================================
# PARSE COMMA-SEPARATED LIST
# ============================================================================

:global ParseCSV do={
  :local Input [ :tostr $1 ];
  :local Result ({});
  :local Current "";
  
  :for I from=0 to=([:len $Input] - 1) do={
    :local Char [:pick $Input $I ($I + 1)];
    :if ($Char = ",") do={
      :local Trimmed $Current;
      # Trim whitespace
      :while ([:len $Trimmed] > 0 && [:pick $Trimmed 0 1] = " ") do={
        :set Trimmed [:pick $Trimmed 1 [:len $Trimmed]];
      }
      :while ([:len $Trimmed] > 0 && [:pick $Trimmed ([:len $Trimmed] - 1) [:len $Trimmed]] = " ") do={
        :set Trimmed [:pick $Trimmed 0 ([:len $Trimmed] - 1)];
      }
      :if ([:len $Trimmed] > 0) do={
        :set ($Result->[:len $Result]) $Trimmed;
      }
      :set Current "";
    } else={
      :set Current ($Current . $Char);
    }
  }
  
  # Don't forget the last item
  :local Trimmed $Current;
  :while ([:len $Trimmed] > 0 && [:pick $Trimmed 0 1] = " ") do={
    :set Trimmed [:pick $Trimmed 1 [:len $Trimmed]];
  }
  :while ([:len $Trimmed] > 0 && [:pick $Trimmed ([:len $Trimmed] - 1) [:len $Trimmed]] = " ") do={
    :set Trimmed [:pick $Trimmed 0 ([:len $Trimmed] - 1)];
  }
  :if ([:len $Trimmed] > 0) do={
    :set ($Result->[:len $Result]) $Trimmed;
  }
  
  :return $Result;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global SharedFunctionsLoaded true;
:log info "Shared functions module loaded"
