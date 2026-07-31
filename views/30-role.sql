-- Current Hats Protocol role holders (mirrors the subgraph `RoleWearer`).
--
-- Hats are ERC-1155-shaped: a grant is a TransferSingle from 0x0, a revocation is one to 0x0.
-- Netting mints against burns gives the live wearer set.
--
-- `value_dec` (exact DECIMAL) is used for the netting — hat balances are 0 or 1. `id` is NOT
-- netted or summed: hat IDs run to ~70 digits, so `id_dec` overflows DECIMAL(38,0) and is always
-- NULL. It is only ever grouped on as exact text, which is correct and lossless.
CREATE VIEW role_wearer AS
WITH moves AS (
    SELECT id, "to" AS wearer, value_dec AS delta, block_number
    FROM "hats__transfer_single"
    WHERE "to" <> '0x0000000000000000000000000000000000000000'
    UNION ALL
    SELECT id, "from" AS wearer, -value_dec AS delta, block_number
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
