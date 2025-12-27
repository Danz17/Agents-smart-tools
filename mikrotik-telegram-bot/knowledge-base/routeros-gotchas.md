# RouterOS Scripting Gotchas & Workarounds

> **Purpose**: Document RouterOS scripting bugs and non-obvious behaviors discovered during TxMTC development.
> **Last Updated**: 2025-01-27

---

## Table of Contents

1. [JSON Serialization Bug](#1-json-serialization-bug)
2. [Array Key Accessor with Underscores](#2-array-key-accessor-with-underscores)
3. [No :continue Statement](#3-no-continue-statement)
4. [UrlEncode Missing Characters](#4-urlencode-missing-characters)
5. [Inline Comments After Braces](#5-inline-comments-after-braces)
6. [Variable Accessor Pattern](#6-variable-accessor-pattern)

---

## 1. JSON Serialization Bug

### Problem
`:serialize to=json` fails with nested arrays, returning `[false]` instead of valid JSON.

### Symptom
```routeros
# This FAILS
:local Buttons ({{{"text"="OK"; "callback_data"="ok"}}});
:local Json [:serialize to=json $Buttons];
:put $Json;
# Output: [false]
```

### Fix
Build JSON string manually:

```routeros
:global CreateInlineKeyboard do={
  :local Buttons $1;
  :local Json "{\"inline_keyboard\":[";
  :local IsFirstRow true;

  :foreach Row in=$Buttons do={
    :if ($IsFirstRow = false) do={ :set Json ($Json . ","); }
    :set IsFirstRow false;
    :set Json ($Json . "[");

    :local IsFirstBtn true;
    :foreach Button in=$Row do={
      :if ($IsFirstBtn = false) do={ :set Json ($Json . ","); }
      :set IsFirstBtn false;
      :local BtnText ($Button->"text");
      :local BtnData ($Button->"callback_data");
      :set Json ($Json . "{\"text\":\"" . $BtnText . "\",\"callback_data\":\"" . $BtnData . "\"}");
    }
    :set Json ($Json . "]");
  }
  :set Json ($Json . "]}");
  :return $Json;
}
```

---

## 2. Array Key Accessor with Underscores

### Problem
The `->` accessor fails with underscore-containing keys when using **unquoted key syntax**.

### Symptom
```routeros
# BROKEN - unquoted key with underscore
:local btn ({text="Test"; callback_data="test:1"});
:put ($btn->"text");           # Works: "Test"
:put ($btn->"callback_data");  # FAILS: returns empty!

# Even with variable accessor
:local k "callback_data";
:put ($btn->$k);               # FAILS: returns empty!
```

### Fix
Use **quoted keys** in array definitions:

```routeros
# WORKS - quoted keys
:local btn ({"text"="Test"; "callback_data"="test:1"});
:put ($btn->"text");           # Works: "Test"
:put ($btn->"callback_data");  # Works: "test:1"
```

### Rule
**ALWAYS quote keys in array definitions when using the `->` accessor.**

```routeros
# Correct pattern for button definitions
{"text"="Label"; "callback_data"="action:data"}

# NOT this (broken with underscore keys)
{text="Label"; callback_data="action:data"}
```

---

## 3. No :continue Statement

### Problem
RouterOS does not have a `:continue` statement for skipping loop iterations.

### Symptom
```routeros
:foreach Item in=$Items do={
  :if ($Item = "skip") do={
    :continue;  # ERROR: bad command name continue
  }
  # process item
}
```

### Fix
Use a `Processed` flag pattern:

```routeros
:foreach Item in=$Items do={
  :local Processed false;

  :if ($Item = "skip") do={
    :set Processed true;
  }

  :if ($Processed = false) do={
    # Process item here
  }
}
```

### Alternative
Use early `:return` if inside a function:

```routeros
:global ProcessItem do={
  :local Item $1;
  :if ($Item = "skip") do={ :return; }
  # Process item
}
```

---

## 4. UrlEncode Missing Characters

### Problem
Custom UrlEncode functions often miss characters required for API calls (especially Telegram API).

### Symptom
```
HTTP 400 Bad Request from Telegram API
```

### Fix
Ensure UrlEncode handles ALL special characters:

```routeros
:global UrlEncode do={
  :local String [ :tostr $1 ];
  :local Result "";
  :local EncodeMap ({
    " "="%20"; "!"="%21"; "\""="%22"; "#"="%23"; "\$"="%24";
    "%"="%25"; "&"="%26"; "'"="%27"; "("="%28"; ")"="%29";
    "*"="%2A"; "+"="%2B"; ","="%2C"; "/"="%2F"; ":"="%3A";
    ";"="%3B"; "<"="%3C"; "="="%3D"; ">"="%3E"; "?"="%3F";
    "@"="%40"; "["="%5B"; "\\"="%5C"; "]"="%5D"; "^"="%5E";
    "`"="%60"; "{"="%7B"; "|"="%7C"; "}"="%7D";
    "\n"="%0A"; "\r"="%0D"; "\t"="%09"
  });

  :for i from=0 to=([:len $String] - 1) do={
    :local Char [:pick $String $i ($i + 1)];
    :local Encoded ($EncodeMap->$Char);
    :if ([:len $Encoded] > 0) do={
      :set Result ($Result . $Encoded);
    } else={
      :set Result ($Result . $Char);
    }
  }
  :return $Result;
}
```

### Critical Characters for Telegram API
| Character | Encoded | Why Needed |
|-----------|---------|------------|
| `{` | `%7B` | JSON in reply_markup |
| `}` | `%7D` | JSON in reply_markup |
| `[` | `%5B` | JSON arrays |
| `]` | `%5D` | JSON arrays |
| `:` | `%3A` | JSON key-value separator |
| `"` | `%22` | JSON strings |
| `,` | `%2C` | JSON separators |

---

## 5. Inline Comments After Braces

### Problem
Inline comments after closing braces cause parse errors with `:import`.

### Symptom
```routeros
# This FAILS when imported
:if ($x = true) do={
  :put "yes";
}  # This is my comment   <-- ERROR HERE

# Error: expected end of command
```

### Fix
Put comments on separate lines:

```routeros
# This is my comment
:if ($x = true) do={
  :put "yes";
}
```

### Note
This only affects `:import` - running directly in terminal may work.

---

## 6. Variable Accessor Pattern

### Problem
Direct string literals with the `->` accessor may fail unexpectedly.

### Symptom
```routeros
:local arr ({"key"="value"});
:put ($arr->"key");           # Sometimes fails
```

### Fix
Use a variable for the key name:

```routeros
:local arr ({"key"="value"});
:local k "key";
:put ($arr->$k);              # Reliable
```

### Best Practice
Define key variables at function start:

```routeros
:global MyFunction do={
  :local KeyText "text";
  :local KeyData "callback_data";

  :foreach Button in=$Buttons do={
    :local BtnText ($Button->$KeyText);
    :local BtnData ($Button->$KeyData);
    # ...
  }
}
```

---

## Quick Reference Table

| Bug | Symptom | Fix |
|-----|---------|-----|
| `:serialize to=json` nested arrays | Returns `[false]` | Build JSON manually |
| `->` with underscore unquoted keys | Returns empty | Use quoted keys: `{"key"=...}` |
| `:continue` statement | "bad command name" | Use `Processed` flag pattern |
| UrlEncode incomplete | 400 errors from APIs | Encode `{}[]:",` and special chars |
| Inline comments after `}` | "expected end of command" | Put comments on separate line |
| Direct string in `->` | May fail | Use variable: `$k="key"; $arr->$k` |

---

## Version Tested
- RouterOS 7.15+
- RB750Gr3, RB5009UG+S+

## Contributing
When discovering new gotchas, add them to this document with:
1. Clear problem description
2. Reproducible symptom
3. Working fix with code example
