#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Shared Functions Module (Enhanced)
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Enhanced with utilities inspired by eworm-de/routeros-scripts

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
        :set Result ($Result . $Char);
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
# JSON ESCAPE (for building JSON strings)
# ============================================================================

:global JsonEscape do={
  :local String [ :tostr $1 ];
  :local Result $String;
  # Escape backslashes first
  :set Result [:replace $Result from="\\" to="\\\\"];
  # Escape quotes
  :set Result [:replace $Result from="\"" to="\\\""];
  # Escape newlines
  :set Result [:replace $Result from="\n" to="\\n"];
  # Escape carriage returns
  :set Result [:replace $Result from="\r" to="\\r"];
  # Escape tabs
  :set Result [:replace $Result from="\t" to="\\t"];
  :return $Result;
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
# VERSION TO NUMBER (for comparison)
# ============================================================================

:global VersionToNum do={
  :local Version [ :tostr $1 ];
  :local Result 0;
  :local Multiplier 1000000;
  :local Current "";
  :for I from=0 to=([:len $Version] - 1) do={
    :local Char [:pick $Version $I ($I + 1)];
    :if ($Char = "." || $Char = "-") do={
      :if ([:len $Current] > 0) do={
        :onerror e { :set Result ($Result + ([:tonum $Current] * $Multiplier)); } do={}
        :set Multiplier ($Multiplier / 1000);
        :set Current "";
      }
    } else={
      :if ($Char ~ "[0-9]") do={
        :set Current ($Current . $Char);
      }
    }
  }
  :if ([:len $Current] > 0) do={
    :onerror e { :set Result ($Result + ([:tonum $Current] * $Multiplier)); } do={}
  }
  :return $Result;
}

# ============================================================================
# COMPARE VERSIONS
# ============================================================================

:global CompareVersions do={
  :local Ver1 [ :tostr $1 ];
  :local Ver2 [ :tostr $2 ];
  :global VersionToNum;
  :local Num1 [$VersionToNum $Ver1];
  :local Num2 [$VersionToNum $Ver2];
  :if ($Num1 > $Num2) do={ :return 1; }
  :if ($Num1 < $Num2) do={ :return -1; }
  :return 0;
}

# ============================================================================
# FORMAT DURATION (Human Readable)
# ============================================================================

:global FormatDuration do={
  :local Seconds [:tonum $1];
  :local Result "";
  :if ($Seconds >= 86400) do={
    :local Days ($Seconds / 86400);
    :set Result ([:tostr $Days] . "d ");
    :set Seconds ($Seconds % 86400);
  }
  :if ($Seconds >= 3600) do={
    :local Hours ($Seconds / 3600);
    :set Result ($Result . [:tostr $Hours] . "h ");
    :set Seconds ($Seconds % 3600);
  }
  :if ($Seconds >= 60) do={
    :local Minutes ($Seconds / 60);
    :set Result ($Result . [:tostr $Minutes] . "m ");
    :set Seconds ($Seconds % 60);
  }
  :if ($Seconds > 0 || [:len $Result] = 0) do={
    :set Result ($Result . [:tostr $Seconds] . "s");
  }
  :return $Result;
}

# ============================================================================
# WAIT FOR CONNECTIVITY
# ============================================================================

:global WaitFullyConnected do={
  :local MaxWait [:tonum $1];
  :if ($MaxWait <= 0) do={ :set MaxWait 30; }
  :local Waited 0;
  :while ($Waited < $MaxWait) do={
    :if ([:len [/ip route find where dst-address="0.0.0.0/0" active=yes]] > 0) do={
      :onerror e { :resolve "www.google.com"; :return true; } do={}
    }
    :delay 1s;
    :set Waited ($Waited + 1);
  }
  :return false;
}

# ============================================================================
# FILE EXISTS
# ============================================================================

:global FileExists do={
  :local FileName [ :tostr $1 ];
  :if ([:len $FileName] = 0) do={ :return false; }
  :local Files [/file find name=$FileName];
  :if ([:len $Files] = 0) do={ :return false; }
  :return true;
}

# ============================================================================
# CERTIFICATE AVAILABLE CHECK
# ============================================================================

:global CertificateAvailable do={
  :local CertName [ :tostr $1 ];
  :if ([:len $CertName] = 0) do={ :return false; }
  :onerror CertErr {
    :local Certs [/certificate find where common-name~$CertName];
    :if ([:len $Certs] > 0) do={ :return true; }
  } do={}
  :return false;
}

# ============================================================================
# VALIDATE SYNTAX
# ============================================================================

:global ValidateSyntax do={
  :local Code [ :tostr $1 ];
  :if ([:pick $Code 0 1] = "/") do={ :return true; }
  :onerror SyntaxErr { :parse $Code; :return true; } do={ :return false; }
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
    :return true;
  } do={ :return false; }
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
        :return $Result;
      }
    }
  } do={}
  :return ({});
}

# ============================================================================
# CASE CONVERSION - TOLOWER
# ============================================================================

:global ToLower do={
  :local Str [:tostr $1];
  :local Result "";
  :local Upper "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  :local Lower "abcdefghijklmnopqrstuvwxyz";
  :for I from=0 to=([:len $Str] - 1) do={
    :local Char [:pick $Str $I ($I + 1)];
    :local Pos [:find $Upper $Char];
    :if ([:typeof $Pos] = "num") do={
      :set Result ($Result . [:pick $Lower $Pos ($Pos + 1)]);
    } else={
      :set Result ($Result . $Char);
    }
  }
  :return $Result;
}

# ============================================================================
# CASE CONVERSION - TOUPPER
# ============================================================================

:global ToUpper do={
  :local Str [:tostr $1];
  :local Result "";
  :local Upper "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  :local Lower "abcdefghijklmnopqrstuvwxyz";
  :for I from=0 to=([:len $Str] - 1) do={
    :local Char [:pick $Str $I ($I + 1)];
    :local Pos [:find $Lower $Char];
    :if ([:typeof $Pos] = "num") do={
      :set Result ($Result . [:pick $Upper $Pos ($Pos + 1)]);
    } else={
      :set Result ($Result . $Char);
    }
  }
  :return $Result;
}

# ============================================================================
# CASE CONVERSION - CAPITALIZE (First letter uppercase)
# ============================================================================

:global Capitalize do={
  :local Str [:tostr $1];
  :if ([:len $Str] = 0) do={ :return ""; }
  :global ToUpper;
  :local First [$ToUpper [:pick $Str 0 1]];
  :if ([:len $Str] = 1) do={ :return $First; }
  :return ($First . [:pick $Str 1 [:len $Str]]);
}

# ============================================================================
# FORMAT NUMBER (with thousand separators)
# ============================================================================

:global FormatNumber do={
  :local Num [:tonum $1];
  :local Result "";
  :local NumStr [:tostr $Num];
  :local DecimalPos [:find $NumStr "."];
  :local IntPart $NumStr;
  :local DecPart "";
  :if ([:typeof $DecimalPos] = "num") do={
    :set IntPart [:pick $NumStr 0 $DecimalPos];
    :set DecPart [:pick $NumStr $DecimalPos [:len $NumStr]];
  }
  :local Count 0;
  :for I from=([:len $IntPart] - 1) to=0 do={
    :if ($Count > 0 && ($Count % 3) = 0) do={
      :set Result ("," . $Result);
    }
    :set Result ([:pick $IntPart $I ($I + 1)] . $Result);
    :set Count ($Count + 1);
  }
  :return ($Result . $DecPart);
}

# ============================================================================
# FORMAT PERCENTAGE (with 1 decimal place)
# ============================================================================

:global FormatPercent do={
  :local Value [:tonum $1];
  :local Result [:tostr ($Value / 10)];
  :local DotPos [:find $Result "."];
  :if ([:typeof $DotPos] = "num") do={
    :set Result [:pick $Result 0 ($DotPos + 2)];
  }
  :return ($Result . "%");
}

# ============================================================================
# FORMAT TEMPERATURE
# ============================================================================

:global FormatTemperature do={
  :local Temp [:tonum $1];
  :return ([:tostr $Temp] . "°C");
}

# ============================================================================
# FORMAT VOLTAGE
# ============================================================================

:global FormatVoltage do={
  :local Volt [:tonum $1];
  :return ([:tostr $Volt] . "V");
}

# ============================================================================
# FORMAT TIME (from timestamp)
# ============================================================================

:global FormatTime do={
  :local Timestamp [:tonum $1];
  :local Clock [/system clock get];
  :local CurrentTime ($Clock->"time");
  :local CurrentDate ($Clock->"date");
  :return ($CurrentTime);
}

# ============================================================================
# FORMAT MESSAGE (User-friendly formatting)
# ============================================================================

:global FormatMessage do={
  :local Title [ :tostr $1 ];
  :local Content [ :tostr $2 ];
  :local Emoji [ :tostr $3 ];
  
  :if ([:len $Emoji] = 0) do={ :set Emoji "⚡"; }
  
  :local Result "";
  :if ([:len $Title] > 0) do={
    :set Result ($Emoji . " *" . $Title . "*\n\n");
  }
  :set Result ($Result . $Content);
  :return $Result;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global SharedFunctionsLoaded true;
:log info "Shared functions module loaded (enhanced)"
