# Performance Optimization Guide

Optimize your MikroTik Telegram Bot for better performance and efficiency.

## Table of Contents
1. [Understanding Resource Usage](#understanding-resource-usage)
2. [Polling Optimization](#polling-optimization)
3. [Monitoring Optimization](#monitoring-optimization)
4. [Memory Management](#memory-management)
5. [Network Optimization](#network-optimization)
6. [Script Optimization](#script-optimization)
7. [Troubleshooting Performance](#troubleshooting-performance)

## Understanding Resource Usage

### Baseline Resource Usage

**Normal Operation:**
- **CPU**: 1-3% during polling (every 30s)
- **Memory**: 5-10MB for scripts and variables
- **Bandwidth**: 1-5KB per poll (~10KB/min)
- **Storage**: 1-5MB for scripts + backups

**During Active Use:**
- **CPU**: 5-15% when executing commands
- **Memory**: +2-5MB for command execution
- **Bandwidth**: Variable based on command output

### Monitoring Resource Usage

```routeros
# Check real-time resources
/system resource print

# Monitor CPU over time
/system resource cpu print

# Check memory details
:put ([/system resource get total-memory] / 1048576)
:put ([/system resource get free-memory] / 1048576)

# Check script execution times
/log print where topics~"script"
```

## Polling Optimization

### Adjust Polling Interval

**Default: 30 seconds**

Lower frequency = less resource usage but slower response time.

```routeros
# For low-traffic scenarios (recommended for most users)
/system scheduler set telegram-bot interval=60s

# For high-priority monitoring
/system scheduler set telegram-bot interval=15s

# For minimal resource usage
/system scheduler set telegram-bot interval=120s
```

**Recommendations:**
- **Home use**: 60s
- **Business critical**: 30s
- **Low-power device**: 90-120s
- **Testing**: 15-30s

### Random Delay

Prevent simultaneous polling on multiple routers:

```routeros
# Default random delay (0-5 seconds)
:global TelegramRandomDelay 5

# Increase for many devices
:global TelegramRandomDelay 15

# Disable for single device
:global TelegramRandomDelay 0
```

### Poll Only When Needed

Conditional polling based on time or events:

```routeros
# Poll only during business hours (8 AM - 6 PM)
/system scheduler set telegram-bot \
  start-time=08:00:00 \
  interval=30s \
  on-event=":if ([/system clock get time] < 18:00:00) do={ /system script run bot-core }"

# Poll more frequently during peak hours
/system scheduler add name="telegram-bot-peak" \
  start-time=09:00:00 \
  interval=15s \
  on-event=":if ([/system clock get time] < 17:00:00) do={ /system script run bot-core }"

/system scheduler set telegram-bot interval=60s
```

## Monitoring Optimization

### Adjust Monitoring Frequency

**Default: 5 minutes**

```routeros
# Less frequent monitoring (lower CPU usage)
/system scheduler set system-monitoring interval=10m

# More frequent monitoring (higher CPU usage)
/system scheduler set system-monitoring interval=2m

# Minimal monitoring
/system scheduler set system-monitoring interval=15m
```

**Recommendations:**
- **Production servers**: 5m
- **Edge devices**: 10m
- **Low-power devices**: 15-30m
- **Critical infrastructure**: 2-3m

### Disable Unnecessary Monitors

```routeros
# Disable automatic monitoring
:global EnableAutoMonitoring false

# Or disable specific monitors by commenting out in monitoring.rsc
# Example: Comment out temperature monitoring if not needed
```

### Optimize Thresholds

Reduce alert frequency by adjusting thresholds:

```routeros
# Higher thresholds = fewer alerts = less processing
:global MonitorCPUThreshold 85   # Instead of 75
:global MonitorRAMThreshold 90   # Instead of 80

# Wider hysteresis for recovery notifications
# (Modify in monitoring.rsc: recover at threshold - 15% instead of -10%)
```

### Monitor Specific Interfaces Only

```routeros
# Monitor only critical interfaces
:global MonitorInterfaces "ether1,bridge"

# Instead of all interfaces
:global MonitorInterfaces ""
```

## Memory Management

### Minimize Variable Scope

```routeros
# ✅ GOOD: Use local variables
:local TempData [/interface print as-value]
:put $TempData
# TempData is freed after script ends

# ❌ BAD: Use global for temporary data
:global TempData [/interface print as-value]
# TempData persists in memory
```

### Clear Large Data Structures

```routeros
# After processing large data
:local LargeArray [/ip firewall connection print as-value]
# ... process data ...
:set LargeArray ({})  # Clear when done
```

### Limit Queue Sizes

```routeros
# In bot-core.rsc, limit message queue
:if ([:len $TelegramQueue] > 50) do={
  # Purge oldest messages
  :set TelegramQueue [:pick $TelegramQueue 25 [:len $TelegramQueue]]
}
```

### Periodic Cleanup

```routeros
# Add cleanup script
/system script add name=memory-cleanup source={
  # Clear old message IDs
  :global TelegramMessageIDs
  :if ([:len $TelegramMessageIDs] > 100) do={
    :set TelegramMessageIDs ({})
  }
  
  # Clear old offset tracking
  :global TelegramChatOffset
  :set TelegramChatOffset { 0; 0; 0 }
}

# Run weekly
/system scheduler add name=memory-cleanup interval=7d \
  on-event="/system script run memory-cleanup"
```

## Network Optimization

### Reduce Payload Size

```routeros
# Use compact command outputs
! router
/ip address print terse

# Instead of:
/ip address print detail

# Filter results
/interface print where running=yes

# Instead of:
/interface print
```

### Batch Commands

```routeros
# ✅ GOOD: Send multiple commands in one message
! router
:put [/system resource get uptime]
:put [/system resource get cpu-load]
:put [/interface ethernet get ether1 running]

# ❌ BAD: Send multiple separate messages
```

### Compress Notifications

```routeros
# Use abbreviations in notifications
:local Msg ("CPU:" . $CPU . "% RAM:" . $RAM . "% UP:" . $Uptime)

# Instead of verbose:
:local Msg ("CPU Usage: " . $CPU . " percent, RAM Usage: " . $RAM . " percent")
```

### Connection Pooling

RouterOS fetch doesn't support persistent connections, but you can:

```routeros
# Batch multiple API calls
:local Updates [/tool fetch url=("https://api.telegram.org/bot" . $Token . "/getUpdates") output=user as-value]
# Process all updates in one go
```

## Script Optimization

### Use Efficient Loops

```routeros
# ✅ GOOD: Direct array access
:foreach Item in=[/interface find] do={
  :local Data [/interface get $Item]
  # Process...
}

# ❌ AVOID: Nested finds
:foreach Name in=[/interface get [find] name] do={
  :local Data [/interface get [find name=$Name]]
}
```

### Cache Repeated Queries

```routeros
# ✅ GOOD: Query once, use multiple times
:local Resource [/system resource get]
:local CPU ($Resource->"cpu-load")
:local RAM ($Resource->"free-memory")

# ❌ BAD: Query multiple times
:local CPU [/system resource get cpu-load]
:local RAM [/system resource get free-memory]
```

### Minimize Log Operations

```routeros
# ✅ GOOD: Log important events only
:if ($ErrorOccurred = true) do={
  :log error "Critical error occurred"
}

# ❌ AVOID: Excessive logging
:log info "Starting function"
:log info "Processing item 1"
:log info "Processing item 2"
# ...
```

### Use Early Returns

```routeros
# ✅ GOOD: Exit early if conditions not met
:if ($Enabled != true) do={
  :error false
}
# Rest of script...

# ❌ BAD: Nest everything
:if ($Enabled = true) do={
  # Entire script indented here
}
```

### Optimize Regular Expressions

```routeros
# ✅ GOOD: Specific patterns
:if ($Message ~ "^/status\$") do={ }

# ❌ SLOW: Broad patterns
:if ($Message ~ "status") do={ }
```

## Troubleshooting Performance

### Identify Bottlenecks

```routeros
# Check scheduler run counts
/system scheduler print

# Look for schedulers with very high run-count relative to others

# Check script execution times in logs
/log print where topics~"script" and message~"finished"

# Identify slow scripts
```

### CPU Profiling

```routeros
# Before optimization
/system resource print
:local Before [/system resource get cpu-load]

# Run your script
/system script run my-script

# After optimization
:delay 1s
:local After [/system resource get cpu-load]
:put ("CPU impact: " . ($After - $Before) . "%")
```

### Memory Profiling

```routeros
# Check memory before
:local MemBefore [/system resource get free-memory]

# Run script
/system script run my-script

# Check memory after
:local MemAfter [/system resource get free-memory]
:put ("Memory used: " . (($MemBefore - $MemAfter) / 1048576) . "MB")
```

### Network Profiling

```routeros
# Monitor interface traffic during bot operation
/interface monitor-traffic ether1 once

# Check total bytes transferred
/interface print stats
```

## Performance Benchmarks

### Typical Performance by Device

| Device Class | CPU Impact | Memory Usage | Recommended Config |
|--------------|------------|--------------|-------------------|
| RB750 | 2-5% | 8-12MB | 60s poll, 10m monitor |
| RB4011 | 1-2% | 5-8MB | 30s poll, 5m monitor |
| CCR1009 | <1% | 5-8MB | 15s poll, 5m monitor |
| CCR2116 | <1% | 5-8MB | 15s poll, 2m monitor |
| CHR (2 vCPU) | 1-3% | 5-10MB | 30s poll, 5m monitor |

### Performance Targets

**Excellent:**
- CPU < 2% average
- Memory < 10MB
- Response time < 5s
- No polling failures

**Good:**
- CPU < 5% average
- Memory < 20MB
- Response time < 10s
- <1% polling failures

**Acceptable:**
- CPU < 10% average
- Memory < 30MB
- Response time < 15s
- <5% polling failures

**Needs Optimization:**
- CPU > 10% average
- Memory > 30MB
- Response time > 15s
- >5% polling failures

## Optimization Checklist

### Initial Setup
- [ ] Set appropriate polling interval for use case
- [ ] Configure monitoring frequency based on needs
- [ ] Disable unnecessary monitors
- [ ] Set realistic alert thresholds
- [ ] Configure backup schedule (off-peak hours)

### Regular Maintenance
- [ ] Review scheduler run counts monthly
- [ ] Check memory usage trends
- [ ] Analyze log for slow operations
- [ ] Optimize frequently-run commands
- [ ] Clear old files and logs

### Advanced Optimization
- [ ] Implement conditional polling
- [ ] Use command batching
- [ ] Optimize regex patterns
- [ ] Cache frequent queries
- [ ] Implement smart rate limiting

## Best Practices

1. **Start Conservative**: Begin with longer intervals, decrease if needed
2. **Monitor First**: Check actual resource usage before optimizing
3. **Test Changes**: Verify optimizations don't break functionality
4. **Document**: Keep notes on performance tweaks
5. **Balance**: Find sweet spot between responsiveness and efficiency

## When to NOT Optimize

Sometimes "good enough" is better than "perfect":

- Router has plenty of resources available
- Current performance meets requirements
- Optimization adds complexity
- Time better spent elsewhere

**Remember**: Premature optimization is the root of all evil. Optimize when needed, not preemptively.

---

**Need help with performance?** Check [FAQ.md](FAQ.md) or ask in the [Telegram Group](https://t.me/routeros_scripts).

