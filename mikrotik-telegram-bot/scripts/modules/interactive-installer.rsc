#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# Interactive Module Installer
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Interactive script installer with auto-detection and Telegram menus
# Dependencies: shared-functions, telegram-api

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :if ($BotConfigReady != true) do={
    :onerror e { /system script run "bot-config"; } do={}
  }

  # ═══════════════════════════════════════════════════════════════
  # MODULE CATALOG
  # ═══════════════════════════════════════════════════════════════

  :global TxMTCModuleCatalog ({
    # Core modules (always required)
    "shared-functions"=({
      name="Shared Functions";
      file="modules/shared-functions.rsc";
      category="core";
      description="Core utility functions";
      required=true;
      autoDetect=""
    });
    "telegram-api"=({
      name="Telegram API";
      file="modules/telegram-api.rsc";
      category="core";
      description="Telegram messaging functions";
      required=true;
      autoDetect=""
    });
    "security"=({
      name="Security Module";
      file="modules/security.rsc";
      category="core";
      description="Command validation and access control";
      required=true;
      autoDetect=""
    });
    "script-registry"=({
      name="Script Registry";
      file="modules/script-registry.rsc";
      category="core";
      description="Module management system";
      required=true;
      autoDetect=""
    });
    "interactive-menu"=({
      name="Interactive Menu";
      file="modules/interactive-menu.rsc";
      category="core";
      description="Telegram inline keyboard menus";
      required=true;
      autoDetect=""
    });
    "user-settings"=({
      name="User Settings";
      file="modules/user-settings.rsc";
      category="core";
      description="Per-user preferences";
      required=true;
      autoDetect=""
    });
    "bot-core"=({
      name="Bot Core";
      file="bot-core.rsc";
      category="core";
      description="Main bot engine";
      required=true;
      autoDetect=""
    });
    "bot-config"=({
      name="Bot Config";
      file="bot-config.rsc";
      category="core";
      description="Configuration variables";
      required=true;
      autoDetect=""
    });

    # Monitoring modules
    "monitoring"=({
      name="System Monitoring";
      file="modules/monitoring.rsc";
      category="monitoring";
      description="CPU, RAM, disk, temperature alerts";
      required=false;
      autoDetect="always"
    });
    "wireless-monitoring"=({
      name="Wireless Monitoring";
      file="modules/wireless-monitoring.rsc";
      category="monitoring";
      description="WiFi client tracking and alerts";
      required=false;
      autoDetect="wireless"
    });
    "netwatch-monitor"=({
      name="Netwatch Monitor";
      file="modules/netwatch-monitor.rsc";
      category="monitoring";
      description="Host/service availability monitoring";
      required=false;
      autoDetect="netwatch"
    });
    "log-monitor"=({
      name="Log Monitor";
      file="modules/log-monitor.rsc";
      category="monitoring";
      description="Forward important logs to Telegram";
      required=false;
      autoDetect="always"
    });
    "cert-monitor"=({
      name="Certificate Monitor";
      file="modules/cert-monitor.rsc";
      category="monitoring";
      description="SSL certificate expiry alerts";
      required=false;
      autoDetect="certificates"
    });

    # Maintenance modules
    "backup"=({
      name="Backup Module";
      file="modules/backup.rsc";
      category="maintenance";
      description="Automated backup management";
      required=false;
      autoDetect="always"
    });
    "update-checker"=({
      name="Update Checker";
      file="modules/update-checker.rsc";
      category="maintenance";
      description="RouterOS update notifications";
      required=false;
      autoDetect="always"
    });
    "daily-summary"=({
      name="Daily Summary";
      file="modules/daily-summary.rsc";
      category="maintenance";
      description="Daily status reports";
      required=false;
      autoDetect="always"
    });

    # Network modules
    "dhcp-to-dns"=({
      name="DHCP to DNS";
      file="modules/dhcp-to-dns.rsc";
      category="network";
      description="Auto DNS records from DHCP leases";
      required=false;
      autoDetect="dhcp"
    });

    # LTE modules
    "sms-actions"=({
      name="SMS Actions";
      file="modules/sms-actions.rsc";
      category="lte";
      description="SMS command handler for LTE routers";
      required=false;
      autoDetect="lte"
    });

    # Utility modules
    "custom-commands"=({
      name="Custom Commands";
      file="modules/custom-commands.rsc";
      category="utility";
      description="User-defined command aliases";
      required=false;
      autoDetect="always"
    });
    "script-discovery"=({
      name="Script Discovery";
      file="modules/script-discovery.rsc";
      category="utility";
      description="Find and manage local scripts";
      required=false;
      autoDetect="always"
    });

    # Installers
    "update-scripts"=({
      name="Update Scripts";
      file="update-scripts.rsc";
      category="installer";
      description="Auto-updater from GitHub";
      required=true;
      autoDetect=""
    });
    "set-credentials"=({
      name="Set Credentials";
      file="set-credentials.rsc";
      category="installer";
      description="Interactive credential setup";
      required=true;
      autoDetect=""
    });
    "load-credentials-from-file"=({
      name="Load Credentials";
      file="load-credentials-from-file.rsc";
      category="installer";
      description="Load credentials from file";
      required=true;
      autoDetect=""
    })
  });

  # ═══════════════════════════════════════════════════════════════
  # AUTO-DETECTION FUNCTIONS
  # ═══════════════════════════════════════════════════════════════

  :global DetectRouterCapabilities do={
    :local Capabilities ({
      wireless=false;
      lte=false;
      dhcp=false;
      certificates=false;
      netwatch=false;
      poe=false;
      gps=false;
      ups=false
    });

    # Check for wireless interfaces
    :onerror e {
      :if ([:len [/interface/wireless/find]] > 0) do={
        :set ($Capabilities->"wireless") true;
      }
    } do={}
    :onerror e {
      :if ([:len [/interface/wifiwave2/find]] > 0) do={
        :set ($Capabilities->"wireless") true;
      }
    } do={}

    # Check for LTE interfaces
    :onerror e {
      :if ([:len [/interface/lte/find]] > 0) do={
        :set ($Capabilities->"lte") true;
      }
    } do={}

    # Check for DHCP server
    :onerror e {
      :if ([:len [/ip/dhcp-server/find]] > 0) do={
        :set ($Capabilities->"dhcp") true;
      }
    } do={}

    # Check for certificates
    :onerror e {
      :if ([:len [/certificate/find where !ca]] > 0) do={
        :set ($Capabilities->"certificates") true;
      }
    } do={}

    # Check for netwatch entries
    :onerror e {
      :if ([:len [/tool/netwatch/find]] > 0) do={
        :set ($Capabilities->"netwatch") true;
      }
    } do={}

    # Check for PoE
    :onerror e {
      :if ([:len [/interface/ethernet/poe/find]] > 0) do={
        :set ($Capabilities->"poe") true;
      }
    } do={}

    # Check for GPS
    :onerror e {
      :if ([:len [/system/gps/find]] > 0) do={
        :set ($Capabilities->"gps") true;
      }
    } do={}

    # Check for UPS
    :onerror e {
      :if ([/system/ups/get connected] = true) do={
        :set ($Capabilities->"ups") true;
      }
    } do={}

    :return $Capabilities;
  }

  # ═══════════════════════════════════════════════════════════════
  # GET RECOMMENDED MODULES
  # ═══════════════════════════════════════════════════════════════

  :global GetRecommendedModules do={
    :global TxMTCModuleCatalog;
    :global DetectRouterCapabilities;

    :local Caps [$DetectRouterCapabilities];
    :local Recommended ({});

    :foreach ModId,ModData in=$TxMTCModuleCatalog do={
      :local AutoDetect ($ModData->"autoDetect");
      :local Required ($ModData->"required");

      :if ($Required = true) do={
        :set ($Recommended->$ModId) "required";
      } else={
        :if ($AutoDetect = "always") do={
          :set ($Recommended->$ModId) "recommended";
        } else={
          :if ($AutoDetect = "wireless" && ($Caps->"wireless") = true) do={
            :set ($Recommended->$ModId) "detected";
          }
          :if ($AutoDetect = "lte" && ($Caps->"lte") = true) do={
            :set ($Recommended->$ModId) "detected";
          }
          :if ($AutoDetect = "dhcp" && ($Caps->"dhcp") = true) do={
            :set ($Recommended->$ModId) "detected";
          }
          :if ($AutoDetect = "certificates" && ($Caps->"certificates") = true) do={
            :set ($Recommended->$ModId) "detected";
          }
          :if ($AutoDetect = "netwatch" && ($Caps->"netwatch") = true) do={
            :set ($Recommended->$ModId) "detected";
          }
        }
      }
    }

    :return $Recommended;
  }

  # ═══════════════════════════════════════════════════════════════
  # MODULE SELECTION STATE
  # ═══════════════════════════════════════════════════════════════

  :global TxMTCInstalledModules;
  :if ([:typeof $TxMTCInstalledModules] != "array") do={
    :global LoadBotState;
    :if ([:typeof $LoadBotState] = "nothing") do={
      :onerror e { /system script run "modules/shared-functions"; } do={}
    }
    :local Loaded [$LoadBotState "installed-modules"];
    :if ([:typeof $Loaded] = "array") do={
      :set TxMTCInstalledModules $Loaded;
    } else={
      :set TxMTCInstalledModules ({});
    }
  }

  # ═══════════════════════════════════════════════════════════════
  # TOGGLE MODULE SELECTION
  # ═══════════════════════════════════════════════════════════════

  :global ToggleModuleSelection do={
    :local ModId $1;
    :global TxMTCModuleCatalog;
    :global TxMTCInstalledModules;
    :global SaveBotState;

    :local ModData ($TxMTCModuleCatalog->$ModId);
    :if ([:typeof $ModData] != "array") do={
      :return ({success=false; error="Module not found"});
    }

    # Cannot toggle required modules
    :if (($ModData->"required") = true) do={
      :return ({success=false; error="Cannot disable required module"});
    }

    :local CurrentState ($TxMTCInstalledModules->$ModId);
    :if ($CurrentState = true) do={
      :set ($TxMTCInstalledModules->$ModId) false;
    } else={
      :set ($TxMTCInstalledModules->$ModId) true;
    }

    [$SaveBotState "installed-modules" $TxMTCInstalledModules];
    :return ({success=true; enabled=($TxMTCInstalledModules->$ModId)});
  }

  # ═══════════════════════════════════════════════════════════════
  # AUTO-SELECT RECOMMENDED MODULES
  # ═══════════════════════════════════════════════════════════════

  :global AutoSelectModules do={
    :global TxMTCModuleCatalog;
    :global TxMTCInstalledModules;
    :global GetRecommendedModules;
    :global SaveBotState;

    :local Recommended [$GetRecommendedModules];
    :local Count 0;

    :foreach ModId,Status in=$Recommended do={
      :set ($TxMTCInstalledModules->$ModId) true;
      :set Count ($Count + 1);
    }

    [$SaveBotState "installed-modules" $TxMTCInstalledModules];
    :return $Count;
  }

  # ═══════════════════════════════════════════════════════════════
  # GET MODULES BY CATEGORY
  # ═══════════════════════════════════════════════════════════════

  :global GetModulesByCategory do={
    :local Category $1;
    :global TxMTCModuleCatalog;
    :local Result ({});

    :foreach ModId,ModData in=$TxMTCModuleCatalog do={
      :if (($ModData->"category") = $Category) do={
        :set ($Result->$ModId) $ModData;
      }
    }
    :return $Result;
  }

  # ═══════════════════════════════════════════════════════════════
  # GENERATE INSTALLER MENU
  # ═══════════════════════════════════════════════════════════════

  :global GenerateInstallerMenu do={
    :global TxMTCModuleCatalog;
    :global TxMTCInstalledModules;
    :global DetectRouterCapabilities;
    :global SendTelegram2;
    :global TelegramChatId;
    :global Identity;

    :local Caps [$DetectRouterCapabilities];

    # Build capability summary
    :local CapsList "";
    :if (($Caps->"wireless") = true) do={ :set CapsList ($CapsList . "WiFi "); }
    :if (($Caps->"lte") = true) do={ :set CapsList ($CapsList . "LTE "); }
    :if (($Caps->"dhcp") = true) do={ :set CapsList ($CapsList . "DHCP "); }
    :if (($Caps->"certificates") = true) do={ :set CapsList ($CapsList . "Certs "); }
    :if (($Caps->"netwatch") = true) do={ :set CapsList ($CapsList . "Netwatch "); }
    :if ([:len $CapsList] = 0) do={ :set CapsList "Basic"; }

    # Count modules by status
    :local InstalledCount 0;
    :local AvailableCount 0;
    :foreach ModId,ModData in=$TxMTCModuleCatalog do={
      :if (($ModData->"required") != true) do={
        :set AvailableCount ($AvailableCount + 1);
        :if (($TxMTCInstalledModules->$ModId) = true) do={
          :set InstalledCount ($InstalledCount + 1);
        }
      }
    }

    :local Message ("*TxMTC Module Installer*\n\n");
    :set Message ($Message . "Router: " . $Identity . "\n");
    :set Message ($Message . "Detected: " . $CapsList . "\n\n");
    :set Message ($Message . "Modules: " . $InstalledCount . "/" . $AvailableCount . " enabled\n\n");
    :set Message ($Message . "Select a category to manage modules:");

    # Build inline keyboard
    :local Keyboard ({
      ({({text="Monitoring"; callback_data="installer:cat:monitoring"})});
      ({({text="Maintenance"; callback_data="installer:cat:maintenance"})});
      ({({text="Network"; callback_data="installer:cat:network"});({text="LTE"; callback_data="installer:cat:lte"})});
      ({({text="Utility"; callback_data="installer:cat:utility"})});
      ({({text="Auto-Select Recommended"; callback_data="installer:auto"})});
      ({({text="Install Selected"; callback_data="installer:install"})})
    });

    :return ({message=$Message; keyboard=$Keyboard});
  }

  # ═══════════════════════════════════════════════════════════════
  # GENERATE CATEGORY MENU
  # ═══════════════════════════════════════════════════════════════

  :global GenerateCategoryMenu do={
    :local Category $1;
    :global TxMTCModuleCatalog;
    :global TxMTCInstalledModules;
    :global GetRecommendedModules;

    :local Recommended [$GetRecommendedModules];
    :local CategoryNames ({
      "monitoring"="Monitoring";
      "maintenance"="Maintenance";
      "network"="Network";
      "lte"="LTE/Mobile";
      "utility"="Utility"
    });
    :local CatName ($CategoryNames->$Category);
    :if ([:len $CatName] = 0) do={ :set CatName $Category; }

    :local Message ("*" . $CatName . " Modules*\n\n");
    :local Keyboard ({});

    :foreach ModId,ModData in=$TxMTCModuleCatalog do={
      :if (($ModData->"category") = $Category) do={
        :local Name ($ModData->"name");
        :local Desc ($ModData->"description");
        :local Enabled ($TxMTCInstalledModules->$ModId);
        :local RecStatus ($Recommended->$ModId);

        :local StatusIcon "";
        :if ($Enabled = true) do={ :set StatusIcon "[ON]"; } else={ :set StatusIcon "[--]"; }
        :if ($RecStatus = "detected") do={ :set StatusIcon ($StatusIcon . " *"); }

        :set Message ($Message . $StatusIcon . " " . $Name . "\n   " . $Desc . "\n\n");

        :local BtnText $Name;
        :if ($Enabled = true) do={ :set BtnText ("Disable " . $Name); } else={ :set BtnText ("Enable " . $Name); }

        :set Keyboard ($Keyboard, ({({text=$BtnText; callback_data=("installer:toggle:" . $ModId)})}));
      }
    }

    :set Keyboard ($Keyboard, ({({text="<< Back"; callback_data="installer:main"})}));

    :return ({message=$Message; keyboard=$Keyboard});
  }

  # ═══════════════════════════════════════════════════════════════
  # INSTALL SELECTED MODULES
  # ═══════════════════════════════════════════════════════════════

  :global InstallSelectedModules do={
    :global TxMTCModuleCatalog;
    :global TxMTCInstalledModules;
    :global TxMTCVersion;

    :local GitHubUser "Danz17";
    :local GitHubRepo "Agents-smart-tools";
    :local GitHubBranch "main";
    :local GitHubPath "mikrotik-telegram-bot/scripts";
    :local BaseURL ("https://raw.githubusercontent.com/" . $GitHubUser . "/" . $GitHubRepo . "/" . $GitHubBranch . "/" . $GitHubPath);

    :local UpdateCount 0;
    :local CreateCount 0;
    :local SkipCount 0;
    :local FailCount 0;
    :local Results ({});

    :foreach ModId,ModData in=$TxMTCModuleCatalog do={
      :local Required ($ModData->"required");
      :local Enabled ($TxMTCInstalledModules->$ModId);

      :if ($Required = true || $Enabled = true) do={
        :local File ($ModData->"file");
        :local Name ($ModData->"name");
        :local URL ($BaseURL . "/" . $File);

        :onerror FetchErr {
          :local ScriptContent ([ /tool/fetch check-certificate=yes-without-crl $URL output=user as-value ]->"data");

          :if ([:len $ScriptContent] > 100) do={
            :local ScriptName $ModId;
            :if ([:find $ModId "/"] < 0) do={
              :set ScriptName $ModId;
            }

            :local ExistingScript [ /system/script/find where name=$ScriptName ];
            :if ([:len $ExistingScript] = 0) do={
              :set ExistingScript [ /system/script/find where name~$ModId ];
            }

            :if ([:len $ExistingScript] > 0) do={
              :local TargetScript [:pick $ExistingScript 0];
              /system/script/set $TargetScript source=$ScriptContent;
              :set UpdateCount ($UpdateCount + 1);
              :set ($Results->$ModId) "updated";
            } else={
              /system/script/add name=$ScriptName owner=admin policy=ftp,read,write,policy,test,password,sniff,sensitive,romon source=$ScriptContent;
              :set CreateCount ($CreateCount + 1);
              :set ($Results->$ModId) "created";
            }
          } else={
            :set FailCount ($FailCount + 1);
            :set ($Results->$ModId) "empty";
          }
        } do={
          :set FailCount ($FailCount + 1);
          :set ($Results->$ModId) $FetchErr;
        }
      } else={
        :set SkipCount ($SkipCount + 1);
        :set ($Results->$ModId) "skipped";
      }
    }

    :return ({
      updated=$UpdateCount;
      created=$CreateCount;
      skipped=$SkipCount;
      failed=$FailCount;
      details=$Results
    });
  }

  # ═══════════════════════════════════════════════════════════════
  # HANDLE INSTALLER CALLBACK
  # ═══════════════════════════════════════════════════════════════

  :global HandleInstallerCallback do={
    :local CallbackData $1;
    :local MessageId $2;
    :global GenerateInstallerMenu;
    :global GenerateCategoryMenu;
    :global ToggleModuleSelection;
    :global AutoSelectModules;
    :global InstallSelectedModules;
    :global EditTelegramMessage;
    :global SendTelegram2;
    :global TelegramChatId;
    :global Identity;

    :local Parts ({});
    :local Pos 0;
    :for I from=0 to=([:len $CallbackData] - 1) do={
      :if ([:pick $CallbackData $I ($I + 1)] = ":") do={
        :set ($Parts->[:len $Parts]) [:pick $CallbackData $Pos $I];
        :set Pos ($I + 1);
      }
    }
    :set ($Parts->[:len $Parts]) [:pick $CallbackData $Pos [:len $CallbackData]];

    :local Action ($Parts->1);
    :local Param ($Parts->2);

    :if ($Action = "main") do={
      :local Menu [$GenerateInstallerMenu];
      :return $Menu;
    }

    :if ($Action = "cat") do={
      :local Menu [$GenerateCategoryMenu $Param];
      :return $Menu;
    }

    :if ($Action = "toggle") do={
      :local Result [$ToggleModuleSelection $Param];
      # Return to category menu
      :global TxMTCModuleCatalog;
      :local ModData ($TxMTCModuleCatalog->$Param);
      :local Cat ($ModData->"category");
      :local Menu [$GenerateCategoryMenu $Cat];
      :return $Menu;
    }

    :if ($Action = "auto") do={
      :local Count [$AutoSelectModules];
      :local Menu [$GenerateInstallerMenu];
      :set ($Menu->"message") (($Menu->"message") . "\n\nAuto-selected " . $Count . " modules!");
      :return $Menu;
    }

    :if ($Action = "install") do={
      # Send progress message
      $SendTelegram2 ({
        chatid=$TelegramChatId;
        silent=true;
        subject=("[" . $Identity . "] Installing modules...");
        message="Please wait..."
      });

      :local Result [$InstallSelectedModules];
      :local Updated ($Result->"updated");
      :local Created ($Result->"created");
      :local Failed ($Result->"failed");

      :local ResultMsg ("*Installation Complete*\n\n");
      :set ResultMsg ($ResultMsg . "Updated: " . $Updated . "\n");
      :set ResultMsg ($ResultMsg . "Created: " . $Created . "\n");
      :set ResultMsg ($ResultMsg . "Failed: " . $Failed . "\n");

      :if ($Failed = 0) do={
        :set ResultMsg ($ResultMsg . "\nAll modules installed successfully!");
      }

      :return ({
        message=$ResultMsg;
        keyboard=({({({text="<< Back to Menu"; callback_data="installer:main"})})})
      });
    }

    :return [$GenerateInstallerMenu];
  }

  :set ExitOK true;
} do={
  :if ($ExitOK = false) do={
    :log error ([:jobname] . " - Script failed: " . $Err);
  }
}

:global InteractiveInstallerLoaded true;
:log info "Interactive installer module loaded"
