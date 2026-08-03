---
name: nuthatch
description: Query this self-hosted nuthatch nest on arbitrum-one - decoded events, balances, and read-only SQL. Use when asked about on-chain activity for these contracts.
---

# Querying the nuthatch nest

Contracts indexed on arbitrum-one:
- `poa_manager` = 0xff585fae4a944cd173b19158c6fc5e08980b0815
- `gov_factory` = 0x24fd3b269905af10a6e5c67d93f0502cd11af875
- `poa_manager_hub` = 0xb72840b343654eafb2cff7acc4fc6b59e6c3cc71
- `hats` = 0x3bc1a0ad72417f2d411118085256fc53cbddd137
- `dkim_registry` = 0xc2ddbc0a6fc4410efe78904bee48558ead0de112
- `implementation_registry` = 0x5e5f4269ef727ffde6a62509c27a7c6c0d39dbb9
- `org_deployer` = 0x1ad59e785e3aec1c53069f78becc24ecfe6a5d1c
- `org_registry` = 0x7b023b9566b96616d54935ae8de80579c93f62ac
- `paymaster_hub` = 0xd6659bcafadcb9cc2f57b7ae923c7f1ca4438a11
- `account_registry` = 0x01a13c92321e9ca2c02577b92a4f8d2fdc4d8513
- `executor` = 0xb1ff2bd0231770ccc91801aa1fae4b3226e1fe41
- `hybrid_voting` = 0x34aa1bd79a3a5eb5d2b208eb4f091ccf6b1081d5
- `dd_voting` = 0xc82b179f5b4e325ac1b77a423fdb266aebfca5e8
- `quick_join` = 0x366c605a3064a680fb5c05bf9eeda512fddbf03a
- `participation_token` = 0x33cd0b9ae54c43c11fd05fe00afd3dbc71d9603e
- `task_manager` = 0x681f29751724d2bed331d3eb35e0c9b1c57af9f0
- `education_hub` = 0xe37db8ccd295c9e4febb19a91efe13ace24ca596
- `payment_manager` = 0xae470b8366af331f52d9ea26efd7cb2d276878b3
- `eligibility_module` = 0xe4f9cb9c843d0a5bd5d52e3266138b13a635743b
- `toggle_module` = 0x14aced4f1b6fb1ef4030e7e7e19a3e6ab0b931a1

Data is local - never call an external API for it.

## Preferred: MCP
If a `nuthatch` MCP server is configured, use its tools. Call `schema` first to learn the
data model, then `sql` / `entity` / `balance` / `top_balances`.

## Fallback: HTTP (a `nuthatch dev` must be running)
- Recent rows:  `curl localhost:8288/entities?limit=20`
- Read-only SQL: `curl -G localhost:8288/sql --data-urlencode 'q=SELECT count(*) FROM transfers'`

`sql` sees finalized data only; balances/entity cover the live tip.
