# TxMTC Modular Architecture Guide

> **Purpose**: Design patterns for extensible, maintainable bot architecture
> **Focus**: Autonomous error handling with Claude Relay integration

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Dependency Management](#dependency-management)
4. [Event System](#event-system)
5. [Error Handling](#error-handling)
6. [Claude Relay Integration](#claude-relay-integration)
7. [Autonomous Error Recovery](#autonomous-error-recovery)
8. [Extension Points](#extension-points)

---

## Architecture Overview

### Current Module Hierarchy

```
bot-config.rsc (Configuration Layer)
    │
    ▼
bot-core.rsc (Core Loop)
    │
    ├── shared-functions.rsc (Utilities)
    ├── telegram-api.rsc (API Wrapper)
    ├── security.rsc (Access Control)
    │
    ├── [Feature Modules]
    │   ├── monitoring.rsc
    │   ├── backup.rsc
    │   ├── interactive-menu.rsc
    │   └── ...
    │
    └── [AI Modules]
        ├── claude-relay.rsc (Python Service)
        └── claude-relay-native.rsc (Direct API)
```

### Module Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| **Core** | Essential bot functionality | bot-core, telegram-api, security |
| **Feature** | User-facing features | monitoring, backup, menu |
| **Utility** | Shared helpers | shared-functions, script-registry |
| **AI** | Intelligence layer | claude-relay, error-suggester |
| **Extension** | Custom additions | user modules |

---

## Module Structure

### Standard Module Template

```routeros
#!rsc by RouterOS
# ═══════════════════════════════════════════════════════════════════════════
# TxMTC - Telegram x MikroTik Tunnel Controller Sub-Agent
# [Module Name]
# ───────────────────────────────────────────────────────────────────────────
# GitHub: https://github.com/Danz17/Agents-smart-tools
# Author: P̷h̷e̷n̷i̷x̷ | Crafted with love & frustration
# ═══════════════════════════════════════════════════════════════════════════
#
# requires RouterOS, version=7.15
#
# [Brief description]
# Dependencies: [list dependencies]

# ============================================================================
# LOADING GUARD
# ============================================================================

:global ModuleNameLoaded;
:if ($ModuleNameLoaded = true) do={
  :return;
}

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

:global SharedFunctionsLoaded;
:if ($SharedFunctionsLoaded != true) do={
  :onerror LoadErr {
    /system script run "modules/shared-functions";
  } do={
    :log error ("[Module] - Failed to load shared-functions: " . $LoadErr);
    :return;
  }
}

# ============================================================================
# IMPORTS
# ============================================================================

:global SendTelegram2;
:global UrlEncode;
:global CertificateAvailable;

# ============================================================================
# MODULE FUNCTIONS
# ============================================================================

:global ModuleFunction do={
  :local Param1 $1;
  :local Param2 $2;

  :onerror FuncErr {
    # Function logic
    :return ({success=true; result="OK"});
  } do={
    :log warning ("[Module] - ModuleFunction failed: " . $FuncErr);
    :return ({success=false; error=$FuncErr});
  }
}

# ============================================================================
# INITIALIZATION
# ============================================================================

:set ModuleNameLoaded true;
:log info "[Module] Module loaded successfully"
```

### Module Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| File | `kebab-case.rsc` | `interactive-menu.rsc` |
| Load Flag | `PascalCaseLoaded` | `InteractiveMenuLoaded` |
| Functions | `PascalCase` | `ShowMainMenu` |
| Local Vars | `camelCase` | `chatId`, `messageText` |
| Global Vars | `PascalCase` | `TelegramTokenId` |
| Constants | `UPPER_SNAKE` | `MAX_RETRY_COUNT` |

---

## Dependency Management

### Dependency Declaration

```routeros
# At top of module, declare dependencies
# Dependencies: shared-functions, telegram-api, security

# Load each dependency with error handling
:global TelegramAPILoaded;
:if ($TelegramAPILoaded != true) do={
  :onerror Err {
    /system script run "modules/telegram-api";
  } do={
    :log error ("Module - Missing dependency: telegram-api");
    :error "Missing dependency: telegram-api";
  }
}
```

### Circular Dependency Prevention

```routeros
# Use loading guards at module start
:global ModuleALoaded;
:if ($ModuleALoaded = true) do={
  :return;  # Already loaded, exit early
}
:set ModuleALoaded true;  # Set flag BEFORE loading deps
```

### Optional Dependencies

```routeros
# For optional features
:global ClaudeRelayLoaded;
:local HasClaudeRelay false;
:if ($ClaudeRelayLoaded = true) do={
  :set HasClaudeRelay true;
}

# Use feature conditionally
:if ($HasClaudeRelay) do={
  # Use Claude Relay
} else={
  # Fallback behavior
}
```

---

## Event System

### Event Types

| Event | Trigger | Handlers |
|-------|---------|----------|
| `message` | New message received | bot-core |
| `callback_query` | Button pressed | interactive-menu |
| `command` | Slash command | bot-core, feature modules |
| `error` | Script error | error-handler |
| `scheduled` | Timer fired | monitoring, backup |

### Event Registration Pattern

```routeros
# Define event handler
:global OnMessageReceived do={
  :local Message $1;
  :local ChatId ($Message->"chat"->"id");
  :local Text ($Message->"text");

  # Process message
  :return ({handled=true});
}

# Register handler (in module init)
:global MessageHandlers;
:if ([:typeof $MessageHandlers] != "array") do={
  :set MessageHandlers ({});
}
:set ($MessageHandlers->"my-module") $OnMessageReceived;
```

### Event Dispatch

```routeros
# In bot-core, dispatch to all handlers
:global MessageHandlers;
:foreach HandlerName,Handler in=$MessageHandlers do={
  :local Result [$Handler $Message];
  :if (($Result->"handled") = true) do={
    :return;  # Stop if handled
  }
}
```

---

## Error Handling

### Standard Error Pattern

```routeros
:global SafeExecute do={
  :local Func $1;
  :local Args $2;

  :onerror ExecErr {
    :local Result [$Func $Args];
    :return ({success=true; result=$Result});
  } do={
    :log error ("SafeExecute - Error: " . $ExecErr);
    :return ({success=false; error=$ExecErr; stack=$Func});
  }
}
```

### Error Logging Format

```routeros
# Standard log format
# [ModuleName] - FunctionName - ErrorType: Details
:log error ("[monitoring] - CheckCPU - Threshold exceeded: " . $CpuLoad . "%");
:log warning ("[telegram-api] - SendMessage - Rate limit: retry in " . $RetryAfter . "s");
:log info ("[backup] - CreateBackup - Success: " . $BackupName);
```

### Error Recovery Strategies

| Error Type | Strategy | Example |
|------------|----------|---------|
| Network | Retry with backoff | 1s, 2s, 4s, 8s |
| Rate Limit | Wait retry_after | Telegram 429 |
| Parse Error | Log and skip | Invalid JSON |
| Auth Error | Alert admin | Token revoked |
| Critical | Disable feature | Continuous failures |

---

## Claude Relay Integration

### Architecture

```
User Message
    │
    ▼
bot-core.rsc
    │
    ├── [Direct Command?] ──► Execute directly
    │
    └── [Natural Language?]
            │
            ▼
     claude-relay.rsc
            │
            ├── [Native Mode] ──► Claude API directly
            │
            └── [Service Mode] ──► Python relay server
                                        │
                                        ▼
                                  Claude API
                                        │
                                        ▼
                              RouterOS Command
                                        │
                                        ▼
                                   Execute
```

### Request Format

```routeros
:global ProcessWithClaude do={
  :local UserMessage $1;
  :local Context $2;

  :local Request ({
    message=$UserMessage;
    context=$Context;
    device_identity=[/system identity get name];
    routeros_version=[/system resource get version];
  });

  # Send to Claude Relay
  :return [$ClaudeRelayProcess $Request];
}
```

### Response Handling

```routeros
:local Response [$ProcessWithClaude $UserMessage $Context];

:if (($Response->"type") = "command") do={
  # Execute RouterOS command
  :local Cmd ($Response->"command");
  :if ([$ValidateCommand $Cmd]) do={
    :onerror ExecErr {
      :local Result [[:parse $Cmd]];
      # Send result to user
    } do={
      # Send error to Claude for suggestion
      [$GetErrorSuggestion $ExecErr $Cmd];
    }
  }
}
```

---

## Autonomous Error Recovery

### Error Detection Loop

```routeros
# Recursive error monitoring script
:global ErrorMonitor do={
  :global LastErrors;
  :global ClaudeRelayNativeEnabled;

  # Check system logs for errors
  :local RecentErrors [/log find where topics~"error" time>([/system clock get time] - 5m)];

  :foreach ErrId in=$RecentErrors do={
    :local ErrMsg [/log get $ErrId message];
    :local ErrTime [/log get $ErrId time];

    # Skip if already processed
    :if ([:typeof ($LastErrors->$ErrId)] = "nothing") do={
      :set ($LastErrors->$ErrId) $ErrTime;

      # Send to Claude for analysis
      :if ($ClaudeRelayNativeEnabled = true) do={
        [$AnalyzeError $ErrMsg];
      }
    }
  }

  # Schedule next run
  /system scheduler add name="error-monitor-next" \
    on-event=":global ErrorMonitor; [\$ErrorMonitor]" \
    start-time=([/system clock get time] + 00:01:00) \
    interval=00:00:00;
}
```

### Error Analysis with Claude

```routeros
:global AnalyzeError do={
  :local ErrorMessage $1;

  :local Prompt ("RouterOS Error Analysis Request:

Error: " . $ErrorMessage . "

Context:
- Device: " . [/system identity get name] . "
- RouterOS: " . [/system resource get version] . "
- Uptime: " . [/system resource get uptime] . "

Please analyze this error and provide:
1. Root cause
2. Suggested fix (RouterOS command if applicable)
3. Prevention steps");

  :global ClaudeRelayNativeProcess;
  :local Response [$ClaudeRelayNativeProcess $Prompt];

  # If auto-execute enabled and fix is safe
  :global ClaudeRelayAutoExecute;
  :if ($ClaudeRelayAutoExecute = true) do={
    :if (($Response->"has_fix") = true) do={
      :local Fix ($Response->"fix_command");
      :if ([$IsSafeCommand $Fix]) do={
        :onerror FixErr {
          [[:parse $Fix]];
          :log info ("[auto-fix] Applied: " . $Fix);
        } do={
          :log warning ("[auto-fix] Failed to apply: " . $Fix);
        }
      }
    }
  }

  # Notify admin
  :global SendTelegram2;
  $SendTelegram2 ({
    chatid=$AdminChatId;
    subject="Error Analysis";
    message=($Response->"analysis")
  });
}
```

### Safe Command Validation

```routeros
:global IsSafeCommand do={
  :local Cmd [ :tostr $1 ];

  # Dangerous command patterns
  :local Dangerous ({
    "/system reset";
    "/system reboot";
    "/file remove";
    "/system script remove";
    "/user remove";
    "/ip firewall filter remove";
  });

  :foreach Pattern in=$Dangerous do={
    :if ($Cmd ~ $Pattern) do={
      :log warning ("[safety] Blocked dangerous command: " . $Cmd);
      :return false;
    }
  }

  :return true;
}
```

---

## Extension Points

### Custom Command Registration

```routeros
# In your extension module
:global RegisterCommand do={
  :local CmdName $1;
  :local Handler $2;
  :local Description $3;

  :global CustomCommands;
  :if ([:typeof $CustomCommands] != "array") do={
    :set CustomCommands ({});
  }

  :set ($CustomCommands->$CmdName) ({
    handler=$Handler;
    description=$Description
  });
}

# Usage
[$RegisterCommand "mycommand" $MyHandler "Does something cool"];
```

### Custom Callback Handler

```routeros
# Register callback prefix handler
:global RegisterCallbackHandler do={
  :local Prefix $1;
  :local Handler $2;

  :global CallbackHandlers;
  :if ([:typeof $CallbackHandlers] != "array") do={
    :set CallbackHandlers ({});
  }

  :set ($CallbackHandlers->$Prefix) $Handler;
}

# In interactive-menu, dispatch to registered handlers
:foreach Prefix,Handler in=$CallbackHandlers do={
  :if ($CallbackData ~ ("^" . $Prefix . ":")) do={
    [$Handler $CallbackData $ChatId $MessageId $ThreadId];
    :return;
  }
}
```

### Custom Monitoring Check

```routeros
# Register custom health check
:global RegisterHealthCheck do={
  :local CheckName $1;
  :local CheckFunc $2;
  :local Threshold $3;

  :global HealthChecks;
  :if ([:typeof $HealthChecks] != "array") do={
    :set HealthChecks ({});
  }

  :set ($HealthChecks->$CheckName) ({
    func=$CheckFunc;
    threshold=$Threshold
  });
}

# Usage
:global CheckMyService do={
  # Return value 0-100 or error
  :return 85;
}
[$RegisterHealthCheck "my-service" $CheckMyService 90];
```

---

## Module Communication

### Message Bus Pattern

```routeros
# Publish-subscribe for loose coupling
:global MessageBus ({});

:global Publish do={
  :local Topic $1;
  :local Data $2;

  :global MessageBus;
  :local Subscribers ($MessageBus->$Topic);

  :if ([:typeof $Subscribers] = "array") do={
    :foreach SubName,Handler in=$Subscribers do={
      :onerror Err {
        [$Handler $Data];
      } do={
        :log warning ("[bus] Subscriber " . $SubName . " failed: " . $Err);
      }
    }
  }
}

:global Subscribe do={
  :local Topic $1;
  :local Name $2;
  :local Handler $3;

  :global MessageBus;
  :if ([:typeof ($MessageBus->$Topic)] != "array") do={
    :set ($MessageBus->$Topic) ({});
  }
  :set (($MessageBus->$Topic)->$Name) $Handler;
}
```

### Usage Example

```routeros
# Module A: Subscribe to errors
[$Subscribe "error" "error-logger" $LogErrorHandler];

# Module B: Publish error
[$Publish "error" ({type="network"; message="Connection failed"})];
```

---

## Best Practices Summary

1. **Always use loading guards** to prevent double-loading
2. **Declare dependencies** at the top of each module
3. **Use error handlers** for all external operations
4. **Log with consistent format** for easy parsing
5. **Return structured results** `{success=bool; result/error=...}`
6. **Validate inputs** before processing
7. **Use event system** for loose coupling
8. **Register extensions** through standard interfaces
9. **Implement graceful degradation** when dependencies fail
10. **Document public functions** with parameters and return types
