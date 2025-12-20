#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# Script Registry Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Script registry system for managing available and installed scripts
# Dependencies: shared-functions

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :log warning "script-registry - shared-functions not loaded, loading now...";
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error "script-registry - Failed to load shared-functions module";
  }
}

# Import shared functions
:global SaveBotState;
:global LoadBotState;
:global CertificateAvailable;

# ============================================================================
# INITIALIZE REGISTRY
# ============================================================================

:global ScriptRegistry;
:if ([:typeof $ScriptRegistry] != "array") do={
  :local LoadedRegistry [$LoadBotState "script-registry"];
  :if ([:typeof $LoadedRegistry] = "array") do={
    :set ScriptRegistry $LoadedRegistry;
  } else={
    :set ScriptRegistry ({});
  }
}

# ============================================================================
# REGISTER SCRIPT
# ============================================================================

:global RegisterScript do={
  :local ScriptId [ :tostr $1 ];
  :local ScriptData $2;
  
  :if ([:typeof $ScriptData] != "array") do={
    :log error "script-registry - RegisterScript: ScriptData must be an array";
    :return false;
  }
  
  # Validate required fields
  :if ([:typeof ($ScriptData->"name")] != "str") do={
    :log error "script-registry - RegisterScript: 'name' field required";
    :return false;
  }
  
  # Set defaults for optional fields
  :if ([:typeof ($ScriptData->"category")] != "str") do={
    :set ($ScriptData->"category") "misc";
  }
  :if ([:typeof ($ScriptData->"description")] != "str") do={
    :set ($ScriptData->"description") "";
  }
  :if ([:typeof ($ScriptData->"source")] != "str") do={
    :set ($ScriptData->"source") "local";
  }
  :if ([:typeof ($ScriptData->"dependencies")] != "array") do={
    :set ($ScriptData->"dependencies") ({});
  }
  :if ([:typeof ($ScriptData->"critical")] != "bool") do={
    :set ($ScriptData->"critical") false;
  }
  :if ([:typeof ($ScriptData->"version")] != "str") do={
    :set ($ScriptData->"version") "1.0.0";
  }
  
  :set ($ScriptRegistry->$ScriptId) $ScriptData;
  [$SaveBotState "script-registry" $ScriptRegistry];
  :log info ("script-registry - Registered script: " . $ScriptId);
  :return true;
}

# ============================================================================
# GET SCRIPT INFO
# ============================================================================

:global GetScriptInfo do={
  :local ScriptId [ :tostr $1 ];
  
  :if ([:typeof ($ScriptRegistry->$ScriptId)] = "array") do={
    :return ($ScriptRegistry->$ScriptId);
  }
  :return;
}

# ============================================================================
# LIST SCRIPTS BY CATEGORY
# ============================================================================

:global ListScriptsByCategory do={
  :local Category [ :tostr $1 ];
  :local Result ({});
  
  :foreach ScriptId,ScriptData in=$ScriptRegistry do={
    :if (($ScriptData->"category") = $Category) do={
      :set ($Result->$ScriptId) $ScriptData;
    }
  }
  :return $Result;
}

# ============================================================================
# LIST ALL SCRIPTS
# ============================================================================

:global ListAllScripts do={
  :return $ScriptRegistry;
}

# ============================================================================
# GET ALL CATEGORIES
# ============================================================================

:global GetCategories do={
  :local Categories ({});
  
  :foreach ScriptId,ScriptData in=$ScriptRegistry do={
    :local Cat ($ScriptData->"category");
    :if ([:typeof ($Categories->$Cat)] = "nothing") do={
      :set ($Categories->$Cat) true;
    }
  }
  
  :local Result ({});
  :foreach Cat,Val in=$Categories do={
    :set ($Result->[:len $Result]) $Cat;
  }
  :return $Result;
}

# ============================================================================
# INSTALL SCRIPT FROM REGISTRY
# ============================================================================

:global InstallScriptFromRegistry do={
  :local ScriptId [ :tostr $1 ];
  :local ScriptData ($ScriptRegistry->$ScriptId);
  
  :if ([:typeof $ScriptData] != "array") do={
    :log error ("script-registry - Script not found in registry: " . $ScriptId);
    :return ({success=false; error="Script not found in registry"});
  }
  
  # Check dependencies
  :local Deps ($ScriptData->"dependencies");
  :if ([:len $Deps] > 0) do={
    :foreach Dep in=$Deps do={
      :if ([:len [/system script find where name=$Dep]] = 0) do={
        :log warning ("script-registry - Missing dependency: " . $Dep);
      }
    }
  }
  
  # Install script
  :local Source ($ScriptData->"source");
  :if ($Source = "local") do={
    :log info ("script-registry - Script is local: " . $ScriptId);
    :return ({success=true; message="Script is already local"});
  }
  
  # Download and install from remote
  :local ScriptName ($ScriptData->"name");
  :onerror InstallErr {
    :local ScriptContent;
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      :set ScriptContent ([ /tool/fetch check-certificate=no output=user \
        $Source as-value ]->"data");
    } else={
      :set ScriptContent ([ /tool/fetch check-certificate=yes-without-crl output=user \
        $Source as-value ]->"data");
    }
    
    :if ([:len $ScriptContent] < 100) do={
      :return ({success=false; error="Downloaded content too short or invalid"});
    }
    
    # Check if script already exists
    :local ExistingScript [/system script find where name=$ScriptName];
    :if ([:len $ExistingScript] > 0) do={
      /system script set $ExistingScript source=$ScriptContent \
        policy=ftp,read,write,policy,test,password,sniff,sensitive,romon;
      :log info ("script-registry - Updated script: " . $ScriptName);
      :return ({success=true; message=("Updated script: " . $ScriptName)});
    } else={
      /system script add name=$ScriptName source=$ScriptContent \
        owner=admin policy=ftp,read,write,policy,test,password,sniff,sensitive,romon;
      :log info ("script-registry - Installed script: " . $ScriptName);
      :return ({success=true; message=("Installed script: " . $ScriptName)});
    }
  } do={
    :log error ("script-registry - Installation failed: " . $InstallErr);
    :return ({success=false; error=$InstallErr});
  }
}

# ============================================================================
# UNINSTALL SCRIPT
# ============================================================================

:global UninstallScript do={
  :local ScriptId [ :tostr $1 ];
  :local ScriptData ($ScriptRegistry->$ScriptId);
  
  :if ([:typeof $ScriptData] != "array") do={
    :return ({success=false; error="Script not found in registry"});
  }
  
  :local ScriptName ($ScriptData->"name");
  :local ExistingScript [/system script find where name=$ScriptName];
  
  :if ([:len $ExistingScript] > 0) do={
    :onerror UninstallErr {
      /system script remove $ExistingScript;
      :log info ("script-registry - Uninstalled script: " . $ScriptName);
      :return ({success=true; message=("Uninstalled script: " . $ScriptName)});
    } do={
      :return ({success=false; error=$UninstallErr});
    }
  } else={
    :return ({success=true; message="Script not installed"});
  }
}

# ============================================================================
# UPDATE REGISTRY FROM REMOTE
# ============================================================================

:global UpdateScriptRegistry do={
  :global ScriptRegistryURL;
  
  :if ([:typeof $ScriptRegistryURL] != "str" || [:len $ScriptRegistryURL] = 0) do={
    :set ScriptRegistryURL "https://raw.githubusercontent.com/Danz17/Agents-smart-tools/main/mikrotik-telegram-bot/scripts-registry";
  }
  
  :local RegistryFile ($ScriptRegistryURL . "/registry.json");
  :onerror UpdateErr {
    :local RegistryData;
    :if ([$CertificateAvailable "ISRG Root X1"] = false) do={
      :set RegistryData ([ /tool/fetch check-certificate=no output=user \
        $RegistryFile as-value ]->"data");
    } else={
      :set RegistryData ([ /tool/fetch check-certificate=yes-without-crl output=user \
        $RegistryFile as-value ]->"data");
    }
    
    :if ([:len $RegistryData] > 0) do={
      :local RemoteRegistry [ :deserialize from=json value=$RegistryData ];
      :if ([:typeof $RemoteRegistry] = "array") do={
        # Merge with existing registry (remote takes precedence)
        :foreach ScriptId,ScriptData in=$RemoteRegistry do={
          :set ($ScriptRegistry->$ScriptId) $ScriptData;
        }
        [$SaveBotState "script-registry" $ScriptRegistry];
        :log info "script-registry - Registry updated from remote";
        :return ({success=true; updated=[:len $RemoteRegistry]});
      }
    }
    :return ({success=false; error="Invalid registry format"});
  } do={
    :log warning ("script-registry - Failed to update registry: " . $UpdateErr);
    :return ({success=false; error=$UpdateErr});
  }
}

# ============================================================================
# SEARCH SCRIPTS
# ============================================================================

:global SearchScripts do={
  :local Query [ :tostr $1 ];
  :local QueryLower [:tolower $Query];
  :local Result ({});
  
  :foreach ScriptId,ScriptData in=$ScriptRegistry do={
    :local NameLower [:tolower ($ScriptData->"name")];
    :local DescLower [:tolower ($ScriptData->"description")];
    :local CatLower [:tolower ($ScriptData->"category")];
    
    :if ($NameLower ~ $QueryLower || $DescLower ~ $QueryLower || $CatLower ~ $QueryLower) do={
      :set ($Result->$ScriptId) $ScriptData;
    }
  }
  :return $Result;
}

# ============================================================================
# INITIALIZE DEFAULT REGISTRY
# ============================================================================

:global InitializeDefaultRegistry do={
  :if ([:len $ScriptRegistry] = 0) do={
    :log info "script-registry - Initializing default registry entries";
    
    # Register built-in modules
    [$RegisterScript "modules/monitoring" ({
      name="System Monitoring";
      category="monitoring";
      description="System health monitoring and alerts";
      version="2.0.0";
      source="local";
      dependencies=({});
      critical=false
    })];
    
    [$RegisterScript "modules/backup" ({
      name="Automated Backup";
      category="backup";
      description="Automated backup creation and management";
      version="2.0.0";
      source="local";
      dependencies=({});
      critical=false
    })];
    
    [$RegisterScript "modules/wireless-monitoring" ({
      name="Wireless Monitoring";
      category="monitoring";
      description="Wireless interface and client monitoring";
      version="2.0.0";
      source="local";
      dependencies=({});
      critical=false
    })];
    
    [$RegisterScript "modules/daily-summary" ({
      name="Daily Summary";
      category="monitoring";
      description="Daily status reports";
      version="2.0.0";
      source="local";
      dependencies=({});
      critical=false
    })];
    
    :log info "script-registry - Default registry initialized";
  }
}

# Auto-initialize on load if registry is empty
:if ([:len $ScriptRegistry] = 0) do={
  [$InitializeDefaultRegistry];
}

# ============================================================================
# INITIALIZATION FLAG
# ============================================================================

:global ScriptRegistryLoaded true;
:log info "Script registry module loaded"
