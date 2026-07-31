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
