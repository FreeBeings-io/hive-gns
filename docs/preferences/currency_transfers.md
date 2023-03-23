# Currency Preferences

Operations to update preferences for notifications in the `currency` module.

- the op_name is `prefs`: to update preferences
- `module` is the key, in this case `currency`
- subsequent keys are for specific notifs (for example, `trn` or `del`), under the relevant module


## HIVE/HBD Transfers

- `min_hbd` is the minimum amount of HBD to be notified about
- `min_hive` is the minimum amount of HIVE to be notified about


```
[
    "prefs",
    {
        "currency": {
            "trn": {
                "min_hbd": 1,
                "min_hive": 0.01
            }
        }
    }
]
```