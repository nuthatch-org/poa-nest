-- The org and its module suite, as of a pinned block.
--
-- Every check in this folder is bounded by block_number so it stays deterministic as the chain
-- advances — `nuthatch check` compares against recorded fixtures, and an unbounded query would
-- drift the moment a new event lands.
--
-- Parity anchors, all verified against Arbitrum One directly:
--   * exactly one org (orgId 0xa71879ef…), deployed at block 447060036
--   * ten modules registered against it in the same transaction
--   * the infrastructure singleton event fired exactly once, at block 447060027
SELECT
    (SELECT count(*) FROM "org_deployer__org_deployed"
       WHERE block_number <= 489620000)                 AS orgs_deployed,
    (SELECT count(*) FROM "org_registry__org_registered"
       WHERE block_number <= 489620000)                 AS orgs_registered,
    (SELECT count(*) FROM "org_registry__contract_registered"
       WHERE block_number <= 489620000)                 AS modules_registered,
    (SELECT count(*) FROM "poa_manager__infrastructure_deployed"
       WHERE block_number <= 489620000)                 AS infra_events,
    (SELECT min(block_number) FROM "org_deployer__org_deployed")  AS org_block;
