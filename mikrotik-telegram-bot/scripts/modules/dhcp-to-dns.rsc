#\!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller
# DHCP to DNS Sync Module
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# Auto-create DNS records from DHCP leases
# Inspired by eworm-de/routeros-scripts dhcp-to-dns
# Dependencies: shared-functions

:local ExitOK false;
:onerror Err {
  :global BotConfigReady;
  :retry { :if ( \!= true) do={ :error "Config not loaded"; }; } delay=500ms max=50;

  :local ScriptName [:jobname];

  # Load dependencies
  :global SharedFunctionsLoaded;
  :if ( \!= true) do={
    :onerror e { /system script run "modules/shared-functions"; } do={}
  }

  # Import functions
  :global CleanName;
  :global CharacterReplace;

  # Import config
  :global EnableDHCPtoDNS;
  :global DHCPDNSDomain;
  :global DHCPDNSNameExtra;

  # Default config values
  :if ([:typeof ] \!= "bool") do={ :set EnableDHCPtoDNS true; }
  :if ([:typeof ] \!= "str") do={ :set DHCPDNSDomain "lan.local"; }
  :if ([:typeof ] \!= "str") do={ :set DHCPDNSNameExtra ""; }

  :if ( \!= true) do={
    :log debug "dhcp-to-dns - Disabled";
    :set ExitOK true;
    :error "Disabled";
  }

  # ═══════════════════════════════════════════════════════════════
  # SYNC DHCP LEASES TO DNS
  # ═══════════════════════════════════════════════════════════════

  :local Comment "TxMTC-DHCP";
  :local AddedCount 0;
  :local UpdatedCount 0;
  :local RemovedCount 0;

  # Process active DHCP leases
  :foreach Lease in=[/ip/dhcp-server/lease find where status="bound"] do={
    :local Mac [/ip/dhcp-server/lease get  mac-address];
    :local IP [/ip/dhcp-server/lease get  address];
    :local Hostname [/ip/dhcp-server/lease get  host-name];

    # Clean MAC for DNS name (remove colons)
    :local MacClean ;
    :set MacClean [  ":" "-"];

    # Build DNS name
    :local DNSName ( . "." . );
    :if ([:len ] > 0) do={
      :set DNSName ( . "." .  . "." . );
    }

    # Check if DNS entry exists
    :local Existing [/ip/dns/static find where name= comment=];

    :if ([:len ] > 0) do={
      # Update if IP changed
      :local ExistingIP [/ip/dns/static get (->0) address];
      :if ( \!= ) do={
        /ip/dns/static set (->0) address=;
        :set UpdatedCount ( + 1);
        :log info ("dhcp-to-dns - Updated: " .  . " -> " . );
      }
    } else={
      # Create new entry
      /ip/dns/static add name= address= comment= ttl=5m;
      :set AddedCount ( + 1);
      :log info ("dhcp-to-dns - Added: " .  . " -> " . );
    }

    # Add CNAME for hostname if available
    :if ([:len ] > 0) do={
      :local HostnameClean [ ];
      :if ([:len ] > 0) do={
        :local CNAMEName ( . "." . );
        :local ExistingCNAME [/ip/dns/static find where name= comment= type="CNAME"];

        :if ([:len ] = 0) do={
          :onerror e {
            /ip/dns/static add name= type=CNAME cname= comment= ttl=5m;
            :log info ("dhcp-to-dns - Added CNAME: " .  . " -> " . );
          } do={}
        }
      }
    }
  }

  # Clean up stale entries
  :foreach Entry in=[/ip/dns/static find where comment=] do={
    :local Name [/ip/dns/static get  name];
    :local Type [/ip/dns/static get  type];

    :if ( = "A") do={
      # Extract MAC from name
      :local MacPart [:pick  0 17];
      :local MacWithColons [  "-" ":"];

      # Check if lease still exists
      :local LeaseExists [/ip/dhcp-server/lease find where mac-address= status="bound"];
      :if ([:len ] = 0) do={
        /ip/dns/static remove ;
        :set RemovedCount ( + 1);
        :log info ("dhcp-to-dns - Removed stale: " . );
      }
    }
  }

  :if ( > 0 ||  > 0 ||  > 0) do={
    :log info ("dhcp-to-dns - Sync complete: Added=" .  . " Updated=" .  . " Removed=" . );
  }

  :set ExitOK true;
} do={
  :if ( = false) do={
    :log error ([:jobname] . " - Script failed: " . );
  }
}

:global DHCPtoDNSLoaded true;
:log info "DHCP to DNS sync module loaded"
