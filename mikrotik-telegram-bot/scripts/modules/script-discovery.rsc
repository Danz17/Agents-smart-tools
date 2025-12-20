#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Script Discovery Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Auto-detect and validate installed scripts
# Dependencies: shared-functions, script-registry

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr { /system script run "modules/shared-functions"; } do={ }
}

:global ScriptRegistryLoaded;
:if ($ScriptRegistryLoaded != true) do={
  :onerror LoadErr { /system script run "modules/script-registry"; } do={ }
}

# Import functions
:global ValidateSyntax;
:global RegisterScript;
:global GetScriptInfo;

# ============================================================================
# EXTRACT SCRIPT METADATA
# ============================================================================

:global ExtractScriptMetadata do={
  :local ScriptSource [ :tostr $1 ];
  :local Metadata ({
    name="";
    category="misc";
    description="";
    version="1.0.0";
    dependencies=({});
    author="";
    source="local"
  });
  
  # Parse header comments for metadata
  :local Lines ({});
  :local CurrentLine "";
  :for I from=0 to=([:len $ScriptSource] - 1) do={
    :local Char [:pick $ScriptSource $I ($I + 1)];
    :if ($Char = "\n") do={
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
  
  # Look for metadata patterns
  :foreach Line in=$Lines do={
    # TxMTC Script: name
    :if ($Line ~ "^# TxMTC Script:") do={
      :local NamePos [:find $Line ":"];
      :if ([:typeof $NamePos] = "num") do={
        :local Name [:pick $Line ($NamePos + 1) [:len $Line]];
        :while ([:pick $Name 0 1] = " ") do={
          :set Name [:pick $Name 1 [:len $Name]];
        }
        :set ($Metadata->"name") $Name;
      }
    }
    
    # Category: category
    :if ($Line ~ "^# Category:") do={
      :local CatPos [:find $Line ":"];
      :if ([:typeof $CatPos] = "num") do={
        :local Cat [:pick $Line ($CatPos + 1) [:len $Line]];
        :while ([:pick $Cat 0 1] = " ") do={
          :set Cat [:pick $Cat 1 [:len $Cat]];
        }
        :set ($Metadata->"category") $Cat;
      }
    }
    
    # Description: description
    :if ($Line ~ "^# Description:") do={
      :local DescPos [:find $Line ":"];
      :if ([:typeof $DescPos] = "num") do={
        :local Desc [:pick $Line ($DescPos + 1) [:len $Line]];
        :while ([:pick $Desc 0 1] = " ") do={
          :set Desc [:pick $Desc 1 [:len $Desc]];
        }
        :set ($Metadata->"description") $Desc;
      }
    }
    
    # Version: version
    :if ($Line ~ "^# Version:") do={
      :local VerPos [:find $Line ":"];
      :if ([:typeof $VerPos] = "num") do={
        :local Ver [:pick $Line ($VerPos + 1) [:len $Line]];
        :while ([:pick $Ver 0 1] = " ") do={
          :set Ver [:pick $Ver 1 [:len $Ver]];
        }
        :set ($Metadata->"version") $Ver;
      }
    }
    
    # Dependencies: dep1,dep2
    :if ($Line ~ "^# Dependencies:") do={
      :local DepPos [:find $Line ":"];
      :if ([:typeof $DepPos] = "num") do={
        :local DepStr [:pick $Line ($DepPos + 1) [:len $Line]];
        :while ([:pick $DepStr 0 1] = " ") do={
          :set DepStr [:pick $DepStr 1 [:len $DepStr]];
        }
        :local Deps ({});
        :local CurrentDep "";
        :for I from=0 to=([:len $DepStr] - 1) do={
          :local Char [:pick $DepStr $I ($I + 1)];
          :if ($Char = ",") do={
            :if ([:len $CurrentDep] > 0) do={
              :set ($Deps->[:len $Deps]) $CurrentDep;
              :set CurrentDep "";
            }
          } else={
            :set CurrentDep ($CurrentDep . $Char);
          }
        }
        :if ([:len $CurrentDep] > 0) do={
          :set ($Deps->[:len $Deps]) $CurrentDep;
        }
        :set ($Metadata->"dependencies") $Deps;
      }
    }
  }
  
  :return $Metadata;
}

# ============================================================================
# SCAN INSTALLED SCRIPTS
# ============================================================================

:global ScanInstalledScripts do={
  :local Result ({});
  :local AllScripts [/system script find];
  
  :foreach Script in=$AllScripts do={
    :local ScriptName [/system script get $Script name];
    :local ScriptSource [/system script get $Script source];
    
    # Skip system scripts and modules
    :if ($ScriptName !~ "^modules/" && $ScriptName != "bot-core" && \
         $ScriptName != "bot-config" && $ScriptName != "global-config" && \
         $ScriptName != "global-functions") do={
      
      :local Metadata [$ExtractScriptMetadata $ScriptSource];
      :if ([:len ($Metadata->"name")] = 0) do={
        :set ($Metadata->"name") $ScriptName;
      }
      
      :set ($Result->$ScriptName) ({
        name=($Metadata->"name");
        category=($Metadata->"category");
        description=($Metadata->"description");
        version=($Metadata->"version");
        dependencies=($Metadata->"dependencies");
        source="local";
        installed=true
      });
    }
  }
  
  :return $Result;
}

# ============================================================================
# VALIDATE SCRIPT
# ============================================================================

:global ValidateScript do={
  :local ScriptName [ :tostr $1 ];
  :local ScriptSource [ :tostr $2 ];
  
  :local Result ({
    valid=false;
    errors=({});
    warnings=({})
  });
  
  # Check syntax
  :if ([$ValidateSyntax $ScriptSource] = true) do={
    :set ($Result->"valid") true;
  } else={
    :set ($Result->"errors"->[:len ($Result->"errors")]) "Syntax validation failed";
  }
  
  # Check for required header
  :if ($ScriptSource !~ "^#!rsc") do={
    :set ($Result->"warnings"->[:len ($Result->"warnings")]) "Missing #!rsc header";
  }
  
  # Check for magic token
  :if ($ScriptSource !~ "by RouterOS") do={
    :set ($Result->"warnings"->[:len ($Result->"warnings")]) "Missing RouterOS magic token";
  }
  
  :return $Result;
}

# ============================================================================
# VALIDATE DEPENDENCIES
# ============================================================================

:global ValidateDependencies do={
  :local Dependencies $1;
  :local Missing ({});
  
  :foreach Dep in=$Dependencies do={
    :if ([:len [/system script find where name=$Dep]] = 0) do={
      :set ($Missing->[:len $Missing]) $Dep;
    }
  }
  
  :return $Missing;
}

# ============================================================================
# CHECK FOR UPDATES
# ============================================================================

:global CheckScriptUpdates do={
  :local ScriptName [ :tostr $1 ];
  :local RemoteSource [ :tostr $2 ];
  
  :if ([:len $RemoteSource] = 0 || $RemoteSource = "local") do={
    :return ({has_update=false; message="No remote source"});
  }
  
  :onerror CheckErr {
    :local RemoteContent;
    :global CertificateAvailable;
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      :set RemoteContent ([ /tool/fetch check-certificate=no output=user \
        $RemoteSource as-value ]->"data");
    } else={
      :set RemoteContent ([ /tool/fetch check-certificate=yes-without-crl output=user \
        $RemoteSource as-value ]->"data");
    }
    
    :if ([:len $RemoteContent] < 100) do={
      :return ({has_update=false; error="Failed to fetch remote script"});
    }
    
    :local LocalSource [/system script get [find name=$ScriptName] source];
    :local LocalVersion "";
    :local RemoteVersion "";
    
    # Extract versions
    :local LocalMeta [$ExtractScriptMetadata $LocalSource];
    :local RemoteMeta [$ExtractScriptMetadata $RemoteContent];
    
    :set LocalVersion ($LocalMeta->"version");
    :set RemoteVersion ($RemoteMeta->"version");
    
    :if ($RemoteVersion != $LocalVersion && [:len $RemoteVersion] > 0) do={
      :return ({
        has_update=true;
        local_version=$LocalVersion;
        remote_version=$RemoteVersion;
        message=("Update available: " . $LocalVersion . " → " . $RemoteVersion)
      });
    }
    
    :return ({has_update=false; message="Script is up to date"});
  } do={
    :return ({has_update=false; error=$CheckErr});
  }
}

# ============================================================================
# SUGGEST SCRIPTS
# ============================================================================

:global SuggestScripts do={
  :local Suggestions ({});
  
  # Check router features and suggest relevant scripts
  :local HasWireless false;
  :onerror WirelessErr {
    :if ([:len [/interface wireless find]] > 0) do={
      :set HasWireless true;
    }
  } do={ }
  
  :local HasUSB false;
  :onerror USBErr {
    :if ([:len [/system resource get usb]] > 0) do={
      :set HasUSB true;
    }
  } do={ }
  
  :local HasPoE false;
  :onerror PoEErr {
    :if ([:len [/interface ethernet poe find]] > 0) do={
      :set HasPoE true;
    }
  } do={ }
  
  # Suggest based on features
  :if ($HasWireless = true) do={
    :set ($Suggestions->[:len $Suggestions]) ({
      script_id="wireless-monitoring";
      reason="Router has wireless interfaces";
      category="monitoring"
    });
  }
  
  :if ($HasUSB = true) do={
    :set ($Suggestions->[:len $Suggestions]) ({
      script_id="usb-reboot";
      reason="Router has USB ports";
      category="utilities"
    });
  }
  
  :if ($HasPoE = true) do={
    :set ($Suggestions->[:len $Suggestions]) ({
      script_id="poe-enable";
      reason="Router supports PoE";
      category="utilities"
    });
  }
  
  # Always suggest monitoring
  :set ($Suggestions->[:len $Suggestions]) ({
    script_id="check-routeros-update";
    reason="Keep RouterOS updated";
    category="monitoring"
  });
  
  :return $Suggestions;
}

# ============================================================================
# AUTO-REGISTER DISCOVERED SCRIPTS
# ============================================================================

:global AutoRegisterDiscoveredScripts do={
  :local Discovered [$ScanInstalledScripts];
  :local Registered 0;
  
  :foreach ScriptName,ScriptData in=$Discovered do={
    :local Existing [$GetScriptInfo $ScriptName];
    :if ([:typeof $Existing] != "array") do={
      :local RegistryData ({
        name=($ScriptData->"name");
        category=($ScriptData->"category");
        description=($ScriptData->"description");
        version=($ScriptData->"version");
        dependencies=($ScriptData->"dependencies");
        source="local";
        critical=false
      });
      :if ([$RegisterScript $ScriptName $RegistryData] = true) do={
        :set Registered ($Registered + 1);
      }
    }
  }
  
  :log info ("script-discovery - Auto-registered " . $Registered . " discovered scripts");
  :return $Registered;
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global ScriptDiscoveryLoaded true;
:log info "Script discovery module loaded"
