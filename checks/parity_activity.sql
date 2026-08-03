-- Governance and work activity as of a pinned block — the numbers a subgraph consumer would
-- actually read. If a decode regresses, these move.
SELECT
    (SELECT count(*) FROM "task_manager__task_created"    WHERE block_number <= 489620000) AS tasks,
    (SELECT count(*) FROM "task_manager__task_completed"  WHERE block_number <= 489620000) AS tasks_completed,
    (SELECT count(*) FROM "task_manager__project_created" WHERE block_number <= 489620000) AS projects,
    (SELECT count(*) FROM "hybrid_voting__new_proposal"   WHERE block_number <= 489620000) AS proposals,
    (SELECT count(*) FROM "hybrid_voting__vote_cast"      WHERE block_number <= 489620000) AS votes,
    (SELECT count(*) FROM "hats__transfer_single"         WHERE block_number <= 489620000) AS hat_transfers,
    (SELECT count(*) FROM "account_registry__user_registered" WHERE block_number <= 489620000) AS members,
    (SELECT count(*) FROM "poa_manager__beacon_created"   WHERE block_number <= 489620000) AS module_types,
    (SELECT count(*) FROM "implementation_registry__implementation_registered"
       WHERE block_number <= 489620000) AS impl_registrations;
