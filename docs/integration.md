# Integrating new notification types

To add support for new notification types, you need to design the following two aspects.

---

### 1) Your SQL functions

These are the SQL functions triggered when new data from the blockchain matches your definitions.

Study the `core_transfers` function to see how HBD and HIVE transfer notifications are handled. This can be found in `/hive_gns/modules/core/functions.sql`

---

### 2) Your Hook JSON file

Hooks use JSON files to define what types of operations your notification type is dependent on and maps that to which functions within GNS to trigger when they are detected.

The JSON files should be stored in the following directory structure: `/hive_gns/modules/{your_app_name}/hooks.json`

Study the default `/hive_gns/modules/core/hooks.json` to learn how to format your JSON file.

```
{
    "core_transfer": [2, "gns.core_transfer", "trn", {}],
    "gns": [18, "gns.core_gns", "gns", {"id":"gns"}]
}
```

- main container is a JSON object
- each key defines your notification type
- within each element is an array, containing:
    - the corresponding HAF operation ID for the notification handler
    - name of the SQL function that handles the body of the operation
    - a 3 character code for the notification handler
    - a JSON object to define a `filter`

`[ hive_op_id <int>, sql_function <str>, notif_code <str(3)> ]`

