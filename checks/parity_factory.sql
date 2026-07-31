-- Factory-discovery invariant: every SwitchableBeacon announced by OrgRegistry.ContractRegistered
-- must appear in the child registry, and nothing else may.
--
-- This is the check that proves the one factory rule in nuthatch.toml is wired correctly. If
-- discovery ever silently stops, `discovered` drops below `announced` and this fails loudly.
-- Both were verified against the chain: 10 beacons, all at block 447060036.
SELECT
    (SELECT count(DISTINCT beacon) FROM "org_registry__contract_registered"
       WHERE block_number <= 489620000)                     AS announced,
    (SELECT count(*) FROM "switchable_beacon__children"
       WHERE discovered_block <= 489620000)                 AS discovered,
    (SELECT count(*) FROM "switchable_beacon__children" c
       WHERE discovered_block <= 489620000
         AND NOT EXISTS (
             SELECT 1 FROM "org_registry__contract_registered" r
             WHERE lower(r.beacon) = lower(c.address)))     AS orphans;
