-- Member entity (mirrors the subgraph `User` / `Account`): a registered username joined to the
-- roles that address currently wears and the participation tokens it has been credited.
CREATE VIEW member AS
SELECT
    u.user                          AS address,
    u.username                      AS username,
    u.block_number                  AS registered_block,
    u.block_timestamp               AS registered_at,
    count(DISTINCT r.hat_id)        AS roles_held,
    coalesce(t.earned, 0)           AS participation_earned
FROM "account_registry__user_registered" u
LEFT JOIN role_wearer r ON lower(r.wearer) = lower(u.user)
LEFT JOIN (
    SELECT "to" AS holder, sum(CAST(value AS DOUBLE)) AS earned
    FROM "participation_token__transfer"
    WHERE "from" = '0x0000000000000000000000000000000000000000'
    GROUP BY "to"
) t ON lower(t.holder) = lower(u.user)
GROUP BY u.user, u.username, u.block_number, u.block_timestamp, t.earned;

-- Gas sponsorship spend per org — what the paymaster hub has actually funded.
CREATE VIEW paymaster_spend AS
SELECT
    orgId                           AS org_id,
    count(*)                        AS sponsored_ops,
    sum(CAST(delta AS DOUBLE))      AS total_delta,
    min(block_number)               AS first_block,
    max(block_number)               AS last_block
FROM "paymaster_hub__usage_increased"
GROUP BY orgId;
