-- Task entity (mirrors the subgraph `Task`): the creation row folded together with whatever
-- lifecycle events later touched it. A task's state is derived, not stored — the contract emits
-- transitions, so the latest one that fired wins.
CREATE VIEW task AS
SELECT
    c.id                        AS id,
    c.project                   AS project_id,
    c.title                     AS title_bytes,
    c.payout                    AS payout,
    c.bountyToken               AS bounty_token,
    c.bountyPayout              AS bounty_payout,
    c.requiresApplication       AS requires_application,
    c.metadataHash              AS metadata_hash,
    c.block_number              AS created_block,
    c.block_timestamp           AS created_at,
    a.assignee                  AS assignee,
    s.block_number              AS submitted_block,
    d.completer                 AS completer,
    d.block_number              AS completed_block,
    CASE
        WHEN d.id IS NOT NULL THEN 'completed'
        WHEN s.id IS NOT NULL THEN 'submitted'
        WHEN a.id IS NOT NULL THEN 'assigned'
        ELSE 'open'
    END                         AS status
FROM "task_manager__task_created" c
LEFT JOIN "task_manager__task_assigned"  a ON a.id = c.id
LEFT JOIN "task_manager__task_submitted" s ON s.id = c.id
LEFT JOIN "task_manager__task_completed" d ON d.id = c.id;
-- No 'cancelled' branch: TaskCancelled has never fired on this deployment, and nuthatch only
-- materialises a table once it has rows — referencing an empty one is a catalog error that
-- fails the whole view. Add the join (and the CASE branch) the day the first task is cancelled.

-- Project entity with its task rollup.
CREATE VIEW project AS
SELECT
    p.id                                            AS id,
    p.title                                         AS title_bytes,
    p.cap                                           AS bounty_cap,
    p.block_number                                  AS created_block,
    count(t.id)                                     AS tasks,
    count(*) FILTER (WHERE t.status = 'completed')  AS tasks_completed,
    count(*) FILTER (WHERE t.status = 'open')       AS tasks_open
FROM "task_manager__project_created" p
LEFT JOIN task t ON t.project_id = p.id
GROUP BY p.id, p.title, p.cap, p.block_number;
