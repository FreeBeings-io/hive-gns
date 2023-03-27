# Notification Options

To update a user account's options for individual notification types, standardised custom_json operations are used.

For more information on the CJOS standard, refer to the [CJOS documentation]().

To broadcast a valid GNS operation, the `custom_json` operation must conform to the CJOS. The `id` field must be set to `gns`, and the `json` field must contain a valid CJOS payload that will be processed by GNS.

For example, this operation sets the options for `transfers` notification type, in the `currency` module. Multiple modules and notification types can be set in a single operation.


`id`: `gns`
`json`:

```
[
        [1, "gns-test/0.1"],
        "options",
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

The entire payload is an array of three elements:

- 1st element: is an array of two elements; the internal operation's version number and the application name and version
- 2nd element: is the internal operation name, as a string
- 3rd element: is the payload for the internal operation, as an object

In the sections below, we will go through each module and notification type, and explain the available options. Note that the JSON samples provided are not the final payload, they still need to be embedded in a full CJOS data payload as in the example above.
