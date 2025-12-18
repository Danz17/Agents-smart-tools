#!rsc by RouterOS
# MikroTik Telegram Bot - Credentials Setup
# This script sets your credentials and makes them persist across reboots

# ============================================================================
# EDIT THESE VALUES WITH YOUR CREDENTIALS
# ============================================================================

:local botToken "8312205498:AAF4CtGBbrtqkZ753hm2WYduEKaBRLekxjM"
:local chatId "579243496"
:local trustedIds "579243496"

# ============================================================================
# DO NOT EDIT BELOW THIS LINE
# ============================================================================

# Set global variables immediately
:global TelegramTokenId $botToken
:global TelegramChatId $chatId
:global TelegramChatIdsTrusted $trustedIds
:global BotConfigReady true

:log info "Telegram Bot credentials set"

# Create or update startup scheduler to persist credentials
:local schedulerName "telegram-bot-credentials"
:local schedulerScript (":global TelegramTokenId \"" . $botToken . "\"; :global TelegramChatId \"" . $chatId . "\"; :global TelegramChatIdsTrusted \"" . $trustedIds . "\"; :global BotConfigReady true")

:if ([:len [/system scheduler find name=$schedulerName]] > 0) do={
    /system scheduler set [find name=$schedulerName] on-event=$schedulerScript
    :log info "Updated credentials scheduler"
} else={
    /system scheduler add name=$schedulerName on-event=$schedulerScript start-time=startup
    :log info "Created credentials scheduler for persistence"
}

# Update the bot-config script source with real credentials
:local configScript [/system script find name="bot-config"]
:if ([:len $configScript] > 0) do={
    :local source [/system script get $configScript source]
    
    # Replace placeholder token
    :local tokenPlaceholder "YOUR_BOT_TOKEN_HERE"
    :local pos [:find $source $tokenPlaceholder]
    :if ([:typeof $pos] = "num") do={
        :set source ([:pick $source 0 $pos] . $botToken . [:pick $source ($pos + [:len $tokenPlaceholder]) [:len $source]])
    }
    
    # Replace placeholder chat ID (first occurrence)
    :local chatPlaceholder "YOUR_CHAT_ID_HERE"
    :set pos [:find $source $chatPlaceholder]
    :if ([:typeof $pos] = "num") do={
        :set source ([:pick $source 0 $pos] . $chatId . [:pick $source ($pos + [:len $chatPlaceholder]) [:len $source]])
    }
    
    # Replace second chat ID placeholder (for trusted IDs)
    :set pos [:find $source $chatPlaceholder]
    :if ([:typeof $pos] = "num") do={
        :set source ([:pick $source 0 $pos] . $trustedIds . [:pick $source ($pos + [:len $chatPlaceholder]) [:len $source]])
    }
    
    /system script set $configScript source=$source
    :log info "Updated bot-config script with credentials"
}

:put ""
:put "=========================================="
:put "CREDENTIALS CONFIGURED SUCCESSFULLY!"
:put "=========================================="
:put ""
:put ("Bot Token: " . [:pick $botToken 0 10] . "...")
:put ("Chat ID: " . $chatId)
:put ("Trusted IDs: " . $trustedIds)
:put ""
:put "Credentials will persist across reboots."
:put ""
:put "Now run: /system script run bot-config"
:put "Then run: /system script run bot-core"
:put ""
