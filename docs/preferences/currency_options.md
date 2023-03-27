# Currency

The `currency` module hosts currency-related notifications, such as transfers or delegations.

## HIVE/HBD Transfers

The notification code for these notifications is `trn`.

- `min_hive`: minimum amount of HIVE to trigger a notification
- `min_hbd`: minimum amount of HBD to trigger a notification

**Example:**

```
"trn": {
    "min_hbd": 1,
    "min_hive": 0.01
}
```