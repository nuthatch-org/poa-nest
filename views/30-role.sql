-- Current Hats Protocol role holders (mirrors the subgraph `RoleWearer`).
--
-- Hats are ERC-1155-shaped: a grant is a TransferSingle from 0x0, a revocation is one to 0x0.
-- Netting mints against burns gives the live wearer set. `id` is a 256-bit hat ID whose `_dec`
-- companion overflows, so the arithmetic is done on CAST(value AS DOUBLE) — safe here because
-- hat balances are 0 or 1, never large.
CREATE VIEW role_wearer AS
WITH moves AS (
    SELECT id, "to" AS wearer, CAST(value AS DOUBLE) AS delta, block_number
    FROM "hats__transfer_single"
    WHERE "to" <> '0x0000000000000000000000000000000000000000'
    UNION ALL
    SELECT id, "from" AS wearer, -CAST(value AS DOUBLE) AS delta, block_number
    FROM "hats__transfer_single"
    WHERE "from" <> '0x0000000000000000000000000000000000000000'
)
SELECT
    id                  AS hat_id,
    wearer              AS wearer,
    sum(delta)          AS balance,
    min(block_number)   AS first_seen_block,
    max(block_number)   AS last_change_block
FROM moves
GROUP BY id, wearer
HAVING sum(delta) > 0;

-- Per-hat holder counts — the quickest read on how a role is distributed.
CREATE VIEW role AS
SELECT
    hat_id,
    count(*)            AS wearers,
    max(last_change_block) AS last_change_block
FROM role_wearer
GROUP BY hat_id;
