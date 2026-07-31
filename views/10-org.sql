-- Organization entity (mirrors the subgraph `Organization`), assembled from the single
-- OrgDeployed event plus its registry row. The subgraph spreads this across OrgDeployer,
-- OrgRegistry and PaymasterHub handlers; here it is one join.
--
-- `name` and `title`-style columns in this system are ABI `bytes`, not `string` — they arrive
-- hex-encoded. Decoding them to text is left to the caller so the view stays lossless.
CREATE VIEW org AS
SELECT
    d.orgId                     AS id,
    d.executor                  AS executor,
    r.name                      AS name_bytes,
    r.metadataHash              AS metadata_hash,
    d.block_number              AS deployed_block,
    d.block_timestamp           AS deployed_at,
    d.tx_hash                   AS deployed_tx,
    d.topHatId                  AS top_hat_id,
    d.roleHatIds                AS role_hat_ids,
    d.hybridVoting              AS hybrid_voting,
    d.directDemocracyVoting     AS dd_voting,
    d.quickJoin                 AS quick_join,
    d.participationToken        AS participation_token,
    d.taskManager               AS task_manager,
    d.educationHub              AS education_hub,
    d.paymentManager            AS payment_manager,
    d.eligibilityModule         AS eligibility_module,
    d.toggleModule              AS toggle_module
FROM "org_deployer__org_deployed" d
LEFT JOIN "org_registry__org_registered" r ON r.orgId = d.orgId;
