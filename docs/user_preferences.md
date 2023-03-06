# GNS User Preferences

GNS allows granular control over notifications. You can enable/disable notifications for specific modules and specific notifications within each module. You can also set custom properties for individual notifications, such as minimum thresholds.

---

## Basic Structure of an Operation

- The main `json` payload is stored in an array
- The first element is the `op_name`; in this case, `prefs`
- The second is the actual payload

**Example:**

`id`: `gns`

`json`: 

```
[
    "prefs",
    {
        "enabled": {
            "currency": ["trn"],
            "splinterlands": ["*"]
        }
    }
]
```

---

## Enabling/Disabling Notifications

To enable or disable notifications, you must specify the module and the notification(s) within that module. You can specify a single notification, multiple notifications, or all notifications (*) within a module.

Each new module preference replaces the previous one. If you want to enable/disable multiple modules in one go, you must specify all of them in the same payload.

**Examples:**

Enable all notifications in the `currency` and `social` modules:

```
[
    "prefs",
    {
        "enabled": {
            "currency": ["*"],
            "social": ["*"]
        }
    }
]
```

Enable the `vot` and `men` notifications in the `social` module:

```
[
    "prefs",
    {
        "enabled": {
            "social": ["vot", "men"]
        }
    }
]
```

Enable all notifications in the `social` and `splinterlands` modules:

```
[
    "prefs",
    {
        "enabled": {
            "social": ["*"],
            "splinterlands": ["*"]
        }
    }
]
```

Disable all notifications in the `currency` module:

```
[
    "prefs",
    {
        "enabled": {
            "currency": []
        }
    }
]
```

---
