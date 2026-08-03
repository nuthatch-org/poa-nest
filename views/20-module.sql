-- Every module proxy registered against an org, resolved to its human-readable type name and
-- the SwitchableBeacon fronting it. `typeId` is keccak(typeName), which is why this join exists:
-- ContractRegistered only carries the hash, and BeaconCreated is the only place the name appears.
CREATE VIEW org_module AS
SELECT
    c.orgId                     AS org_id,
    b.typeName                  AS type_name,
    c.typeId                    AS type_id,
    c.proxy                     AS proxy,
    c.beacon                    AS beacon,
    c.autoUpgrade               AS auto_upgrade,
    c.owner                     AS owner,
    c.contractId                AS contract_id,
    c.block_number              AS registered_block,
    c.block_timestamp           AS registered_at
FROM "org_registry__contract_registered" c
LEFT JOIN "poa_manager__beacon_created" b ON b.typeId = c.typeId;

-- Full registration history of every module implementation, with its version string.
--
-- `latest` is the flag as it was set AT REGISTRATION — events are immutable, so it is never
-- retroactively cleared when a newer implementation lands. Most types therefore have several
-- rows with is_latest_at_registration = true. It answers "was this registered as latest?", NOT
-- "is this current?". Use module_current_version below for the latter.
CREATE VIEW module_version AS
SELECT
    typeId                      AS type_id,
    typeName                    AS type_name,
    version                     AS version,
    implementation              AS implementation,
    latest                      AS is_latest_at_registration,
    versionId                   AS version_id,
    block_number                AS registered_block,
    block_timestamp             AS registered_at
FROM "implementation_registry__implementation_registered";

-- The current implementation per module type: the most recent registration that claimed `latest`,
-- ordered by (block, log_index).
--
-- Deliberately ordered by block, NOT by the version string. Version labels are not monotonic in
-- this deployment — EligibilityModule registered v11 at block 458043730 and then v4 at 467001431 —
-- so "highest version" and "most recently registered" are different questions, and only the second
-- is answerable from the event log. If you need the value the contract itself would return today,
-- that is an eth_call, which this nest deliberately does not make.
CREATE VIEW module_current_version AS
SELECT type_id, type_name, version, implementation, registered_block, registered_at
FROM (
    SELECT *, row_number() OVER (
        PARTITION BY type_id ORDER BY registered_block DESC, version_id DESC
    ) AS rn
    FROM module_version
    WHERE is_latest_at_registration
)
WHERE rn = 1;

-- Protocol-wide upgrade history per module type: when each type was last upgraded and to what.
-- BeaconUpgraded is the busiest infrastructure table in this nest.
CREATE VIEW module_type AS
SELECT
    b.typeId                    AS type_id,
    b.typeName                  AS type_name,
    b.beacon                    AS protocol_beacon,
    b.implementation            AS initial_implementation,
    b.block_number              AS created_block,
    count(u.newImplementation)  AS upgrade_count,
    max(u.block_number)         AS last_upgrade_block
FROM "poa_manager__beacon_created" b
LEFT JOIN "poa_manager__beacon_upgraded" u ON u.typeId = b.typeId
GROUP BY b.typeId, b.typeName, b.beacon, b.implementation, b.block_number;
