# POA nest

A [nuthatch](https://github.com/nuthatch-org/nuthatch) indexer for the **POA** DAO-tooling stack
on Arbitrum One — a drop-in replacement for subgraph
`QmRx2fUCpZ3B8q1uLfL3XKAb4H6XPHtSE4GLmf2UT2YczQ`, which has been stuck syncing for days.

**It syncs in 66 seconds.**

| | Subgraph | This nest |
|---|---|---|
| Blocks to scan | 43,530,436 | 43,530,436 |
| Events in that range | 951 | 951 |
| Time to fully synced | still going, days | **66 seconds** |

Same chain, same contracts, same 951 events. The difference is entirely in how the work is done —
see [Why the subgraph is stuck](#why-the-subgraph-is-stuck).

You don't need to know anything about nuthatch to use this. It's a single Rust binary that reads
the chain over plain JSON-RPC and gives you a local SQL database plus an HTTP API. No Postgres, no
Docker, no IPFS, no hosted service, no API key, no rate limits, no bill. It runs on your laptop.

---

## TL;DR

```sh
cargo install --git https://github.com/nuthatch-org/nuthatch nuthatch   # or the install.sh one-liner
cd poa

# 1. Backfill the whole history (~60s), then Ctrl-C once it says "sealing history done".
nuthatch dev --seal-direct --window 50000 --rpc https://your-arbitrum-archive-node/

# 2. Start it again. This run serves the API and follows the tip.
nuthatch dev --window 50000 --rpc https://your-arbitrum-archive-node/
```

Then query it:

```sh
nuthatch sql --url http://127.0.0.1:8288 "SELECT status, count(*) FROM task GROUP BY status"
```

> **Why two steps?** Views in `views/*.sql` are loaded once, at startup. On a cold start there is
> no data yet, so every view fails with `Catalog Error: Table … does not exist` and you get raw
> tables only. Restarting after the backfill loads them all. You only ever pay this once — from
> then on a single `nuthatch dev` is all you need.

---

## Why the subgraph is stuck

It isn't data volume. Measured directly against Arbitrum One, the entire deployment is:

- **1** organisation deployed (orgId `0xa71879ef…`, block 447,060,036)
- **951** events, total, across 43.5M blocks
- **10** module proxies and their beacons

That is a rounding error of a workload. It's been stuck for days on something that fits in a
spreadsheet. The cause is the manifest's *shape*, not its size — 7 static data sources and
**30 templates**, of which:

**10 are `file/ipfs` data sources.** Org names, task descriptions, proposal bodies. Every one is a
blocking IPFS fetch that graph-node must resolve before it can advance. If a CID is slow, unpinned,
or simply gone, indexing stalls behind it — and nothing about that failure is visible as "the chain
is fine, the metadata isn't".

**20 are Ethereum templates.** Each org deployment spawns ~15 dynamic data sources, and every one
widens the block-stream filter that gets evaluated per block.

nuthatch takes the opposite approach on both counts:

- **Wide `eth_getLogs` windows** — 50,000 blocks per request, so 43.5M blocks is ~870 requests
  rather than a per-block stream. This is the whole ballgame for a sparse contract set.
- **Nothing on the indexing path touches IPFS.** Metadata *hashes* are indexed as ordinary columns
  (`metadata_hash`), so you can fetch and join them client-side, on your own schedule, and a dead
  CID costs you one NULL instead of the entire sync.

The honest caveat: this nest doesn't index IPFS metadata content, because that's precisely the part
that breaks. If you need those strings, fetch them from the hashes — decoupled, and restartable.

---

## Prerequisites

**An Arbitrum archive RPC endpoint.** This is the one thing that matters, and the free public ones
mostly can't do it. A usable endpoint must serve all three of:

- `eth_getLogs` over a wide block range (this nest uses 50,000-block windows)
- JSON-RPC **batches larger than 3** (the block-timestamp fetcher batches requests)
- archive history back to block 447,059,849

Measured on the free public endpoints:

| Endpoint | Wide getLogs | Batch >3 | Verdict |
|---|---|---|---|
| `arb1.arbitrum.io/rpc` | ✅ | ✅ | works, but rate-limits into partial timestamp responses near the tip |
| `arbitrum-one.public.blastapi.io` | ❌ capped | ✅ | timestamp fallback only |
| `1rpc.io/arb` | ❌ 50-block cap | ✅ | no |
| `arbitrum.drpc.org` | — | ❌ free plan caps at 3 | no — timestamps never complete |
| `arb-pokt.nodies.app` | ❌ 403 | — | no |

`nuthatch.toml` ships with the two workable public endpoints so the nest runs out of the box, but
**use your own node** via `--rpc` for anything real. `--rpc` is tried first and keeps the
configured endpoints as fallback, which also means your private URL never has to enter the repo.

---

## Running it

```sh
# First run: seal the whole history to Parquet. Ctrl-C at "sealing history done".
nuthatch dev --seal-direct --window 50000 --rpc https://your-node/

# Every run after that: resumes where it stopped, loads the views, follows the tip.
nuthatch dev --window 50000 --rpc https://your-node/
```

What the flags do:

- `--seal-direct` — write finalised history straight to Parquet, skipping the hot store. Much
  faster for a from-scratch backfill. Drop it on subsequent runs.
- `--window 50000` — how many blocks per `eth_getLogs` call. This system is extremely sparse (951
  events across 43.5M blocks), so a wide window turns ~850 requests into a job that finishes in
  minutes. Lower it if your provider rejects the range.
- `--rpc` — your endpoint, tried ahead of the configured ones.

`dev` **is** the serve command — there is no separate "start the API" step. It prints a progress
line during backfill, then `✓ caught up to tip … now following`.

To run it as a service, put that command under systemd or Docker behind a reverse proxy. If you
expose it off localhost, set `NUTHATCH_ADMIN_TOKEN`.

---

## Querying it

### SQL from the shell

```sh
nuthatch sql "SELECT * FROM org"
nuthatch sql                      # no argument opens a REPL: .tables, .schema <t>, history
nuthatch sql --json "SELECT * FROM task" | jq   # newline-delimited JSON for piping
```

If `nuthatch dev` is running it holds the store, so point the CLI at the API instead:

```sh
nuthatch sql --url http://127.0.0.1:8288 "SELECT * FROM org"
```

### Over HTTP

```sh
curl 'localhost:8288/'                                  # status, table count, sealed_through
curl 'localhost:8288/schema'                            # the whole data model, with footguns
curl 'localhost:8288/tables'                            # every table and its columns
curl 'localhost:8288/table/task_manager__task_created?limit=10'
curl 'localhost:8288/sql?q=SELECT%20count(*)%20FROM%20task'
curl 'localhost:8288/metrics'                           # Prometheus: tip lag, last block
```

### From an AI agent

```sh
nuthatch mcp --print-config       # prints copy-paste MCP client config
claude mcp add poa -- nuthatch mcp --url http://127.0.0.1:8288
```

The agent gets a `schema` tool (including the footguns below) and a `sql` tool. Entirely offline —
nothing phones home.

---

## The data model

Two layers: **raw event tables**, and **views** that assemble them into the entities the subgraph
exposed.

### Views (start here)

| View | What it is |
|---|---|
| `org` | The organisation, with all ten module addresses as columns |
| `org_module` | Each registered module resolved to its human-readable type name and beacon |
| `module_version` | Every implementation registration, with version strings |
| `module_current_version` | The current implementation per module type |
| `module_type` | Protocol-wide module types and their upgrade counts |
| `role_wearer` | Current Hats Protocol role holders (mints netted against burns) |
| `role` | Holder count per hat |
| `task` | Tasks with derived status: `open` / `assigned` / `submitted` / `completed` |
| `project` | Projects with task rollups |
| `proposal` | Governance proposals with vote counts and outcomes |
| `member` | Registered users, roles held, participation tokens earned |
| `paymaster_spend` | Gas sponsorship per org |

```sh
nuthatch sql "SELECT type_name, auto_upgrade FROM org_module ORDER BY type_name"
nuthatch sql "SELECT status, count(*) FROM task GROUP BY status"
nuthatch sql "SELECT username, roles_held, participation_earned FROM member ORDER BY roles_held DESC"
```

Views live in `views/*.sql`, load in filename order, and are plain `CREATE VIEW` statements — edit
them freely. They're recomputed per query, never materialised.

### Raw tables

One table per contract event, named `{alias}__{event_snake_case}` — so `TaskCreated` on the task
manager is `task_manager__task_created`. 207 tables exist; ~130 have rows. `curl localhost:8288/schema`
lists all of them with descriptions and warnings.

The aliases are `poa_manager`, `gov_factory`, `poa_manager_hub`, `hats`, `dkim_registry`,
`org_deployer`, `org_registry`, `paymaster_hub`, `account_registry`, `implementation_registry`,
`executor`, `hybrid_voting`,
`dd_voting`, `quick_join`, `participation_token`, `task_manager`, `education_hub`,
`payment_manager`, `eligibility_module`, `toggle_module`, plus `switchable_beacon` for the
factory-discovered children.

Every table also carries `block_number`, `block_timestamp`, `block_hash`, `tx_hash`, `log_index`
and `address`.

### Four gotchas that will bite you

1. **`from` and `to` are SQL reserved words.** Double-quote them:
   `SELECT "from", "to" FROM hats__transfer_single`.
2. **Big integers are stored as exact text.** `uint256` columns sort and compare as strings. Most
   have a `_dec` companion for arithmetic, but columns wider than 128 bits (hat IDs, task payouts)
   overflow it — use `CAST(col AS DOUBLE)` there. The views already do this.
3. **`name` and `title` are ABI `bytes`, not strings.** They arrive hex-encoded. The views expose
   them as `*_bytes` unchanged rather than guessing an encoding — decode them client-side.
4. **A table only exists once it has rows.** Referencing an event that has never fired is a
   DuckDB catalog error that fails the *entire* view file. This is why `views/50-proposal.sql`
   has the direct-democracy half commented out and `views/40-task.sql` has no `cancelled` branch —
   those events haven't happened yet. Uncomment them when they do. It's also why a cold start
   needs a restart before the views appear (see the TL;DR): at first launch *no* table has rows.

---

## How this differs from the subgraph

The subgraph's structure doesn't survive contact with nuthatch's model, and mostly shouldn't.

**Singletons became static contracts.** `OrgDeployer`, `OrgRegistry`, `PaymasterHub` and
`UniversalAccountRegistry` are *templates* in the subgraph, spawned by
`PoaManager.InfrastructureDeployed`. But that event fires exactly once, at block 447,060,027 — so
their addresses are knowable in advance and pinning them costs nothing. They're static contracts
here, and cheaper for it.

**The org's ten modules are pinned, not discovered.** `OrgDeployer.OrgDeployed` announces all ten
in a single event, one address per named parameter. They *cannot* be ten nuthatch factory rules:
nuthatch keys factory rules by `{watch}__{event}`, so ten rules on `org_deployer__org_deployed`
would collide and only one would survive. They also can't share a single template, because five
event **names** in this system carry two different signatures — `VoteCast`, `Winner`, `PauseSet`,
`OrgRegistered`, `BatchExecuted` — and nuthatch names tables per event *name*, so a shared template
would put two incompatible decoders on one table. Giving each module its own alias keeps
`hybrid_voting__vote_cast` and `dd_voting__vote_cast` cleanly separate, which is the whole point.

**One genuine factory survived.** Each module is fronted by a `SwitchableBeacon`, announced by
`OrgRegistry.ContractRegistered` — one event, one child type, N children. That's the shape factories
are for, and it's declared in `nuthatch.toml`. It keeps working for orgs deployed after this nest
was written, with no config change. `checks/parity_factory.sql` asserts discovery stays complete.

**Three templates were dropped as dead.** `PasskeyAccountFactory`, `PasskeyAccount` and
`ZkEmailInvites` have never been instantiated on this deployment —
`UniversalAccountRegistry.PasskeyFactoryUpdated` has never fired. `PoaManagerSatellite` is also
skipped: the subgraph points it at the **zero address**, which is a bug on their side. Arbitrum is
the hub chain, so satellites live elsewhere anyway.

**Event coverage is a superset.** The subgraph allowlists specific handlers. This nest omits
`events = [...]` filters entirely, so every event in every ABI is decoded — you get strictly more
than the subgraph exposed.

**The ABIs are the subgraph's own.** Fetched from the IPFS CIDs its manifest pins, not from
Sourcify. Every module here is a beacon proxy, so Sourcify would return the proxy ABI, which
contains none of the real events.

**No IPFS metadata.** The 10 `file/ipfs` data sources — org names, task descriptions, proposal
bodies — are not indexed. Their content hashes *are* (`metadata_hash`, `metadataHash`), so you can
fetch and join them client-side. This is deliberate: those fetches are precisely what makes the
subgraph stall, and nuthatch keeps the indexing path deterministic and offline.

---

## Maintenance

**A new org deploys.** The `SwitchableBeacon` children are picked up automatically. Its ten module
proxies are not — add them as contracts:

```sh
nuthatch add 0xNewHybridVoting 0xNewTaskManager --alias hv2,tm2
```

Read the new addresses off `org_deployer__org_deployed`, which will have a second row.

**A new event starts firing.** Uncomment the relevant view block (see gotcha 4) and restart.

**Verify nothing regressed.**

```sh
nuthatch check --dir .        # stop `nuthatch dev` first — check reads the store directly
```

Runs `checks/*.sql` against recorded fixtures. All three are bounded by `block_number <= 489620000`
so they stay deterministic as the chain advances. Re-record with `--update` after an intentional
change.

---

## Layout

```
nuthatch.toml     20 contracts, 1 template, 1 factory rule — the whole config
abis/             20 ABIs, vendored from the subgraph's own IPFS CIDs
views/            10 entity views as plain CREATE VIEW SQL
checks/           3 invariant checks + their recorded fixtures
semantic.toml     what each table means (agents read this via the schema tool)
schema.json       DERIVED from nuthatch.toml — drives the `_dec` columns
llms.txt          DERIVED — the AI-facing surface
segments/         sealed Parquet history — regenerable, safe to delete
nuthatch.redb     the hot store near the tip — regenerable, safe to delete
```

**If you hand-edit `nuthatch.toml`, run `nuthatch schema` afterwards.** `schema.json` and
`llms.txt` are derived artifacts, and `schema.json` is what generates the `_dec` companion columns.
Without it every `_dec` column silently disappears — while `/schema` still advertises them, so
queries that follow its advice fail. Regenerating takes a second:

```sh
nuthatch schema --dir .
```

Delete `segments/` and `nuthatch.redb` to force a clean rebuild. It takes about a minute.
