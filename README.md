# Global Notification System (Hive Blockchain)


<p align="center">
  <img src="./logo.png" />
</p>


<p align="center">A global notification system for dApps on the Hive Blockchain</p>

---

## What is GNS?

GNS is a global notification system for dApps on the Hive Blockchain. It utilizes the HAF framework to retrieve and maintain relevant data sets from the Hive blockchain. It is completely open-source and any one can run a node to serve the notification system. The goal is to have multiple nodes running, giving multiple sources of truth.

---

## Production Deployment

Simply build from the Dockerfile and run the container with the following variables passed:

```
DB_HOST=127.0.0.1
DB_NAME=haf_block_log
DB_USERNAME=postgres
DB_PASSWORD=password
SERVER_HOST=127.0.0.3
PORT=8080
MAIN_SCHEMA=gns_dev
RESET=false
```

To reset the database, set the `RESET` variable to true.

---

## Documentation

- [User Preferences](/docs/preferences/user_preferences.md)
  - [GNS Notifications Options](/docs/preferences/notification_options.md)
  - [Currency Options](/docs/preferences/currency_options.md)
- [Integrating New Notifications](/docs/integration.md)
- [HAF Internal Op IDs](/docs/haf_op_ids.md)

---

## Features

*Status of features.*

### Hive Core

**Currency:**

- [x] HIVE/HBD transfers
- [ ] Power up
- [ ] Power down
- [ ] Vest withdrawals
- [x] Delegations received
- [x] Delegations removed
- [x] Author reward
- [x] Curation reward
- [x] Comment benefactor reward
- [ ] Filled conversion request
- [ ] Filled order
- [ ] Recurrent transfer
- [ ] Transfer from savings


**Social Interactions:**

- [x] Votes
- [x] Comments
- [ ] Reblogs
- [ ] Follows
- [ ] Unfollows
- [x] Mentions

**Comunities (WIP):**

- [ ] Subscribe
- [ ] Unsubscribe
- [ ] Role assignment
- [ ] Properties update
- [ ] Post mute
- [ ] Post unmute

---

### Splinterlands (WIP)

- [x] DEC transfers

---

### Hive Engine (WIP)

- [ ] Token transfers