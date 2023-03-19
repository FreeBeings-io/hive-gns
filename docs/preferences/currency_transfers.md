
## Account preferences

- the op_name is `prefs`: to update preferences
- `module` is the key
- subsequent keys are for specific notifs (`trn` | `vot`), under the relevant module

```
[
    "prefs",
    {
        "currency": {
            "trn": {
                "min_hbd": 1,
                "min_hive": 0.01
            },
            "vot": {
                "min_weight": 12345,
                "freq": 12,                         # hours
                "summary": true
            }

        },
        "splinterlands": {
            "trn": {
                "min_dec": 1
            }
        }
    }
]
```