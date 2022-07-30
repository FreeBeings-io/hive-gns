# HAF Internal Operation IDs

***Filtering examples are provided. (for use in a hook's `filter` value)

- `1` | `comment_operation`

```
{"type":"comment_operation","value":{"parent_author":"","parent_permlink":"hive-132410","author":"imwatsi.test","permlink":"test-1","title":"Test 1","body":"This is a test post","json_metadata":"{\"app\":\"peakd/2022.03.9\",\"format\":\"markdown\",\"tags\":[\"test\",\"post\"]}"}}
```

---

- `2` | `transfer_operation`

```
{"type":"transfer_operation","value":{"from":"ksmith7","to":"orinoco","amount":{"amount":"110000","precision":3,"nai":"@@000000013"},"memo":"fd4ccb59d550"}}
```

---

- `3` | `transfer_to_vesting_operation`

```
{"type":"transfer_to_vesting_operation","value":{"from":"giftgiver","to":"hatdogsensei","amount":{"amount":"2","precision":3,"nai":"@@000000021"}}}
```

---

- `4` | `withdraw_vesting_operation`

```
{"type":"withdraw_vesting_operation","value":{"account":"soulreaperx","vesting_shares":{"amount":"156179349187","precision":6,"nai":"@@000000037"}}}
```

---

- `5` | `limit_order_create_operation`

```
{"type":"limit_order_create_operation","value":{"owner":"yakubenko","orderid":1648923025,"amount_to_sell":{"amount":"7898","precision":3,"nai":"@@000000013"},"min_to_receive":{"amount":"6422","precision":3,"nai":"@@000000021"},"fill_or_kill":false,"expiration":"2022-04-29T18:07:37"}}
```

---

- `6` | `limit_order_cancel_operation`

```
{"type":"limit_order_cancel_operation","value":{"owner":"kevinnag58","orderid":1648861081}}
```

---

- `7` | `feed_publish_operation`

```
{"type":"feed_publish_operation","value":{"publisher":"aggroed","exchange_rate":{"base":{"amount":"1234","precision":3,"nai":"@@000000013"},"quote":{"amount":"1000","precision":3,"nai":"@@000000021"}}}}
```

---

- `8` | `convert_operation`

```
{"type":"convert_operation","value":{"owner":"uapb","requestid":3983729890,"amount":{"amount":"4000","precision":3,"nai":"@@000000013"}}}
```

---

- `9` | `account_create_operation`

```
{"type":"account_create_operation","value":{"fee":{"amount":"3000","precision":3,"nai":"@@000000021"},"creator":"wallet.creator","new_account_name":"ouchi","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM7Z1jk55NEAkuuysE55r5R2Ni1DJvmCvMqcXyFTPoKsg87vZon1",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Jitmb1KzUpGcvtWsVDfWWdHC5otgAUSE5gYqju85e7NESLApM",1]]},"posting":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM8SqWwKieAcSsgUVoZbxVbDGnjUp9CoJKK2CT8z3pHqhGUrKBmL",1]]},"memo_key":"STM8aomYntfWtiFa9YsdLxiCg3MP6WTvhgAkS65dJKX7p5M1XsME3","json_metadata":"{\"profile\":{\"about\":\"This account was instantly created via @hivewallet.app - available for iOS and Android!\",\"website\":\"https://hivewallet.app\"}}"}}
```

---

- `10` | `account_update_operation`

```
{"type":"account_update_operation","value":{"account":"majesticsym","posting":{"weight_threshold":1,"account_auths":[["ecency.app",1]],"key_auths":[["STM5sT6mPPyodR64FYqkWhiKDZBcEZ4YcDZ6quuCoiHVy3wmkvEkD",1]]},"memo_key":"STM7jLZ23hfdw4mYXVCmzD5ZYVVLMmqt3EpyN6R2Mpanr2U4FJgWb","json_metadata":""}}
```

---

- `11` | `witness_update_operation`

```
{"type":"witness_update_operation","value":{"owner":"perfilbrasil","url":"https://peakd.com/hive/@fernandosoder/important-things-to-be-considered-regarding-vulnerabilities-on-hive-blockchain","block_signing_key":"STM7Wgnx1XySbk3D4p33qyfMq7okSwetfHA1nu5cNB3XBAMZj9JCs","props":{"account_creation_fee":{"amount":"3000","precision":3,"nai":"@@000000021"},"maximum_block_size":65536,"hbd_interest_rate":1200},"fee":{"amount":"0","precision":3,"nai":"@@000000021"}}}
```

---

- `12` | `account_witness_vote_operation`

```
{"type":"account_witness_vote_operation","value":{"account":"aiyumi","witness":"perfilbrasil","approve":true}}
```

---

- `13` | `account_witness_proxy_operation`

```
{"type":"account_witness_proxy_operation","value":{"account":"sdoyle","proxy":"thehive"}}
```

---

- `17` | `delete_comment_operation`
```
{"type":"delete_comment_operation","value":{"author":"karevska","permlink":"predstavyane-v-ecency"}}
```

---

- `18` | `custom_json_operation`

```
{"type":"custom_json_operation","value":{"required_auths":[],"required_posting_auths":["john-jerry"],"id":"notify","json":["setLastRead",{"date":"2022-05-10T11:20:37"}]}}
```

- Filtering example:

```
{
    "id": "notify"
}
```

---

-  `19` | `comment_options_operation`

```
{"type":"comment_options_operation","value":{"author":"waivio.updates06","permlink":"monterey-uwk98dj2pcj","max_accepted_payout":{"amount":"100000000","precision":3,"nai":"@@000000013"},"percent_hbd":0,"allow_votes":true,"allow_curation_rewards":true,"extensions":[{"type":"comment_payout_beneficiaries","value":{"beneficiaries":[{"account":"monterey","weight":7000},{"account":"waivio","weight":1500},{"account":"waivio.updates06","weight":1500}]}}]}}
```

---

- `20` | `set_withdraw_vesting_route_operation`

```
{"type":"set_withdraw_vesting_route_operation","value":{"from_account":"amama","to_account":"smqwl","percent":10000,"auto_vest":false}}
```

---

- `22` | `claim_account_operation`

```
{"type":"claim_account_operation","value":{"creator":"steemmonsters","fee":{"amount":"0","precision":3,"nai":"@@000000021"},"extensions":[]}}
```

---

- 23 | `create_claimed_account_operation`

```
{"type":"create_claimed_account_operation","value":{"creator":"appreciator","new_account_name":"ganicus","owner":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6BiV1BiFmTBfm89hGBuaX6eQ8jot2LrWN31V3x6HfsKyBPTYoo",1]]},"active":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM4wf862nWae266gCgpQpT3bQDaXvG4pNtmzYfCLasYeAtdVVVoP",1]]},"posting":{"weight_threshold":1,"account_auths":[["ecency.app",1]],"key_auths":[["STM8XASCiTfGMNUYz7NYkNhXxpLpYAZcnWJ7cF97LZgFGNxQr18Fm",1]]},"memo_key":"STM83rViQfn7TLJjN8nmqbAxRfxdyXh2qM52eC4FqHcAXtCpopNKJ","json_metadata":"","extensions":[]}}
```

---

- `24` | `request_account_recovery_operation`

```
{"type":"request_account_recovery_operation","value":{"recovery_account":"ocd","account_to_recover":"doziekash","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM6Zbv34Xjr6W8hnaig1prx1nEvssrtg1QdB5uPg8qFSRNgBM1iH",1]]},"extensions":[]}}
```

---

- `25` | `recover_account_operation`

```
{"type":"recover_account_operation","value":{"account_to_recover":"abrarhussain","new_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5ybqmMzeoDWpEtqVUvTfDGRq7PbfFtrkchHuRp3BawfQZao4XZ",1]]},"recent_owner_authority":{"weight_threshold":1,"account_auths":[],"key_auths":[["STM5RiJi2duByxjHyCZcGosTMVFVw9UimPDTkvR9VJP2Tg2hUuxwM",1]]},"extensions":[]}}
```

---

- `26` | `change_recovery_account_operation`

```
{"type":"change_recovery_account_operation","value":{"account_to_recover":"aaronnn","new_recovery_account":"steemmonsters","extensions":[]}}
```

---

- `32` | `transfer_to_savings_operation`

```
{"type":"transfer_to_savings_operation","value":{"from":"thealliance","to":"thealliance","amount":{"amount":"5517","precision":3,"nai":"@@000000013"},"memo":""}}
```

---

- `33` | `transfer_from_savings_operation`

```
{"type":"transfer_from_savings_operation","value":{"from":"nilomck1","request_id":3798413040,"to":"nilomck1","amount":{"amount":"1434","precision":3,"nai":"@@000000013"},"memo":""}}
```

---

- `34` | `cancel_transfer_from_savings_operation`

```
{"type":"cancel_transfer_from_savings_operation","value":{"from":"mornevd","request_id":1648750192}}
```

---

- `39` | `claim_reward_balance_operation`

```
{"type":"claim_reward_balance_operation","value":{"account":"marpa","reward_hive":{"amount":"0","precision":3,"nai":"@@000000021"},"reward_hbd":{"amount":"0","precision":3,"nai":"@@000000013"},"reward_vests":{"amount":"66130093","precision":6,"nai":"@@000000037"}}}
```

---

- `40` | `delegate_vesting_shares_operation`

```
{"type":"delegate_vesting_shares_operation","value":{"delegator":"steemmonsters","delegatee":"nyc925","vesting_shares":{"amount":"24000000000","precision":6,"nai":"@@000000037"}}}
```

---

- `42` | `witness_set_properties_operation`

```
{"type":"witness_set_properties_operation","value":{"owner":"cadawg","props":[["hbd_exchange_rate","97040000000000000353424400000000e80300000000000003535445454d0000"],["key","0276b36311a84e996f94a9bdcf6937867c00d8602a731ea9d9bea60aaa95ff0a0a"]],"extensions":[]}}
```

---

- `43` | `account_update2_operation`

```
{"type":"account_update2_operation","value":{"account":"lilypoesy","json_metadata":"","posting_json_metadata":"{\"profile\":{\"name\":\"Lily Poesy\",\"location\":\"Belgium\",\"version\":2}}","extensions":[]}}
```

---

- `45` | `update_proposal_votes_operation`

```
{"type":"update_proposal_votes_operation","value":{"voter":"leo1102","proposal_ids":[174],"approve":true,"extensions":[]}}
```

---

- `48` | `collateralized_convert_operation`

```
{"type":"collateralized_convert_operation","value":{"owner":"the-bitcoin-dood","requestid":1,"amount":{"amount":"9000","precision":3,"nai":"@@000000021"}}}
```

---

- `49` | `recurrent_transfer_operation`

```
{"type":"recurrent_transfer_operation","value":{"from":"overorlando","to":"orinoco","amount":{"amount":"685","precision":3,"nai":"@@000000021"},"memo":"3ea9e510ed73","recurrence":24,"executions":2,"extensions":[]}}
```

---

- `50` | `fill_convert_request_operation`

```
{"type":"fill_convert_request_operation","value":{"owner":"ua-ethnology","requestid":6,"amount_in":{"amount":"1022","precision":3,"nai":"@@000000013"},"amount_out":{"amount":"872","precision":3,"nai":"@@000000021"}}}
```

---

- `51` | `author_reward_operation`

```
{"type":"author_reward_operation","value":{"author":"dbooster","permlink":"re-scaredycatguide-r9d7ky","hbd_payout":{"amount":"8","precision":3,"nai":"@@000000013"},"hive_payout":{"amount":"0","precision":3,"nai":"@@000000021"},"vesting_payout":{"amount":"12856764","precision":6,"nai":"@@000000037"},"curators_vesting_payout":{"amount":"22040167","precision":6,"nai":"@@000000037"},"payout_must_be_claimed":true}}
```

---

- `52` | `curation_reward_operation`

```
{"type":"curation_reward_operation","value":{"curator":"jagoe","reward":{"amount":"62447195","precision":6,"nai":"@@000000037"},"comment_author":"lacausa","comment_permlink":"oathvaay","payout_must_be_claimed":true}}
```

