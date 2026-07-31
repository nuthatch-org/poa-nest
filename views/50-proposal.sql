-- Proposal entity (mirrors the subgraph `Proposal`).
--
-- Only the hybrid module has ever seen a proposal on this deployment. The direct-democracy
-- module is deployed and configured but has never had one, so `dd_voting__new_proposal` has no
-- rows — and nuthatch only materialises a table once it has rows, so referencing it here would
-- be a catalog error that fails the whole view. The commented block at the bottom is the DDV
-- half, ready to paste in the day the first direct-democracy proposal lands.
--
-- Worth knowing if you plan to merge them: the two modules emit NewProposal with an identical
-- signature, but their VoteCast events do NOT — hybrid carries per-class raw powers and a
-- timestamp, direct democracy carries neither. That divergence is exactly why this nest gives
-- each module its own table namespace instead of sharing one template.
CREATE VIEW proposal AS
SELECT
    'hybrid'                AS module,
    p.id                    AS id,
    p.title                 AS title_bytes,
    p.descriptionHash       AS description_hash,
    p.numOptions            AS num_options,
    p.created               AS created_ts,
    p.endTs                 AS end_ts,
    p.block_number          AS created_block,
    count(DISTINCT v.voter) AS voters,
    w.winningIdx            AS winning_idx,
    w.valid                 AS valid,
    w.executed              AS executed
FROM "hybrid_voting__new_proposal" p
LEFT JOIN "hybrid_voting__vote_cast" v ON v.id = p.id
LEFT JOIN "hybrid_voting__winner"    w ON w.id = p.id
GROUP BY p.id, p.title, p.descriptionHash, p.numOptions, p.created, p.endTs,
         p.block_number, w.winningIdx, w.valid, w.executed;

-- UNION ALL
-- SELECT
--     'direct_democracy'      AS module,
--     p.id                    AS id,
--     p.title                 AS title_bytes,
--     p.descriptionHash       AS description_hash,
--     p.numOptions            AS num_options,
--     p.created               AS created_ts,
--     p.endTs                 AS end_ts,
--     p.block_number          AS created_block,
--     count(DISTINCT v.voter) AS voters,
--     w.winningIdx            AS winning_idx,
--     w.valid                 AS valid,
--     NULL                    AS executed   -- DDV's Winner carries no `executed` flag
-- FROM "dd_voting__new_proposal" p
-- LEFT JOIN "dd_voting__vote_cast" v ON v.id = p.id
-- LEFT JOIN "dd_voting__winner"    w ON w.id = p.id
-- GROUP BY p.id, p.title, p.descriptionHash, p.numOptions, p.created, p.endTs,
--          p.block_number, w.winningIdx, w.valid;
