enum CanonicalCatalogSchema {
    static let creationStatements = [
        "CREATE TABLE library_roots (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL UNIQUE, is_enabled INTEGER NOT NULL DEFAULT 1, display_order INTEGER NOT NULL DEFAULT 0, created_at REAL NOT NULL, last_scan_started_at REAL, last_scan_completed_at REAL, last_scan_track_count INTEGER NOT NULL DEFAULT 0, last_scan_error TEXT, is_attached INTEGER NOT NULL DEFAULT 1, game_sidebar_buckets_dirty INTEGER NOT NULL DEFAULT 1, file_sidebar_buckets_dirty INTEGER NOT NULL DEFAULT 1);",
        "CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, root_id INTEGER NOT NULL, folder_path TEXT NOT NULL, path TEXT NOT NULL, filename TEXT NOT NULL, extension TEXT NOT NULL, browser_game TEXT NOT NULL DEFAULT '', browser_system TEXT NOT NULL DEFAULT '', track_index INTEGER NOT NULL DEFAULT 0, track_count INTEGER NOT NULL DEFAULT 1, track_number INTEGER, file_size INTEGER NOT NULL, modified_at REAL NOT NULL, discovered_at REAL NOT NULL, archive_path TEXT, archive_entry TEXT, UNIQUE(root_id, path, archive_entry, track_index), FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE track_metadata (track_id INTEGER PRIMARY KEY, title TEXT NOT NULL DEFAULT '', game TEXT NOT NULL DEFAULT '', author TEXT NOT NULL DEFAULT '', system TEXT NOT NULL DEFAULT '', comment TEXT NOT NULL DEFAULT '', intro_length_ms INTEGER NOT NULL DEFAULT 0, loop_length_ms INTEGER NOT NULL DEFAULT 0, play_length_ms INTEGER NOT NULL DEFAULT 0, fade_length_ms INTEGER NOT NULL DEFAULT 0, metadata_scanned_at REAL NOT NULL, FOREIGN KEY(track_id) REFERENCES tracks(id) ON DELETE CASCADE);",
        "CREATE TABLE track_metadata_tags (track_id INTEGER NOT NULL, tag_index INTEGER NOT NULL, tag_name TEXT NOT NULL, normalized_name TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(track_id, tag_index), FOREIGN KEY(track_id) REFERENCES tracks(id) ON DELETE CASCADE);",
        "CREATE TABLE scan_items (id INTEGER PRIMARY KEY AUTOINCREMENT, root_id INTEGER NOT NULL, path TEXT NOT NULL, archive_entry TEXT NOT NULL DEFAULT '', file_size INTEGER NOT NULL, modified_at REAL NOT NULL, content_signature TEXT, state TEXT NOT NULL, plugin_id TEXT, format_extension TEXT, supports_archive_members INTEGER NOT NULL DEFAULT 0, supports_multi_track INTEGER NOT NULL DEFAULT 0, structure_policy TEXT NOT NULL DEFAULT 'knownSingle', metadata_policy TEXT NOT NULL DEFAULT 'decoder', failure_stage TEXT, failure_message TEXT, updated_at REAL NOT NULL, UNIQUE(root_id, path, archive_entry), FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE scan_staging_roots (staging_root_id INTEGER PRIMARY KEY, target_root_id INTEGER NOT NULL, created_at REAL NOT NULL, state TEXT NOT NULL DEFAULT 'paused', mode TEXT NOT NULL DEFAULT 'newScan', policy_version INTEGER NOT NULL DEFAULT 1, updated_at REAL NOT NULL DEFAULT 0, last_error TEXT, FOREIGN KEY(staging_root_id) REFERENCES library_roots(id) ON DELETE CASCADE, FOREIGN KEY(target_root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE scan_source_checkpoints (staging_root_id INTEGER NOT NULL, path TEXT NOT NULL, file_size INTEGER NOT NULL, modified_at REAL NOT NULL, content_signature TEXT, updated_at REAL NOT NULL, PRIMARY KEY(staging_root_id, path), FOREIGN KEY(staging_root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE dead_sources (root_id INTEGER NOT NULL, path TEXT NOT NULL, marked_at REAL NOT NULL, PRIMARY KEY(root_id, path), FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE game_sidebar_buckets (root_id INTEGER NOT NULL, browser_game TEXT NOT NULL, browser_system TEXT NOT NULL, track_count INTEGER NOT NULL, PRIMARY KEY(root_id, browser_game, browser_system), FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE TABLE file_sidebar_buckets (root_id INTEGER NOT NULL, folder_path TEXT NOT NULL, path TEXT NOT NULL, is_archive INTEGER NOT NULL, track_count INTEGER NOT NULL, PRIMARY KEY(root_id, path), FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE);",
        "CREATE INDEX tracks_browser_bucket_index ON tracks(browser_game, browser_system, root_id);",
        "CREATE INDEX tracks_file_tree_index ON tracks(root_id, folder_path, path);",
        "CREATE INDEX tracks_source_lookup_index ON tracks(root_id, path);",
        "CREATE INDEX track_metadata_tags_name_index ON track_metadata_tags(normalized_name, track_id);",
        "CREATE INDEX tracks_game_sidebar_index ON tracks(browser_game, browser_system, root_id, path);",
        "CREATE INDEX scan_items_state_index ON scan_items(root_id, state);",
        "CREATE INDEX scan_staging_target_index ON scan_staging_roots(target_root_id);",
        "CREATE INDEX scan_checkpoints_stage_index ON scan_source_checkpoints(staging_root_id, path);",
        "CREATE INDEX dead_sources_path_index ON dead_sources(path);",
        "CREATE INDEX file_sidebar_buckets_tree_index ON file_sidebar_buckets(root_id, folder_path, path);",
        "PRAGMA user_version=25;"
    ]

    // Additive schema-25 projection. Existing readers can ignore this table.
    static let resolvedGameBucketsStatement = """
        CREATE TABLE IF NOT EXISTS resolved_game_sidebar_buckets (
            root_id INTEGER NOT NULL,
            prefer_folders INTEGER NOT NULL,
            browser_game TEXT NOT NULL,
            system TEXT NOT NULL,
            track_count INTEGER NOT NULL,
            PRIMARY KEY(root_id, prefer_folders, browser_game, system),
            FOREIGN KEY(root_id) REFERENCES library_roots(id) ON DELETE CASCADE
        );
        """

    static var resolvedGameInvalidationStatements: [String] {
        var statements = ["""
            CREATE TABLE resolved_game_sidebar_state (
                root_id INTEGER PRIMARY KEY REFERENCES library_roots(id) ON DELETE CASCADE,
                is_current INTEGER NOT NULL
            );
            """]
        // Database-owned invalidation also protects these projections when an
        // older schema-25 writer publishes without knowing about the new table.
        for (table, root) in [
            ("tracks", "{row}.root_id"),
            ("track_metadata", "(SELECT root_id FROM tracks WHERE id={row}.track_id)"),
            ("dead_sources", "{row}.root_id")
        ] {
            for (event, rows) in [("INSERT", ["NEW"]), ("DELETE", ["OLD"]), ("UPDATE", ["OLD", "NEW"])] {
                let roots = rows.map { root.replacingOccurrences(of: "{row}", with: $0) }.joined(separator: ", ")
                statements.append("""
                    CREATE TRIGGER resolved_games_\(table)_\(event.lowercased()) AFTER \(event) ON \(table)
                    BEGIN
                        UPDATE resolved_game_sidebar_state SET is_current=0
                        WHERE is_current=1 AND root_id IN (\(roots));
                    END;
                    """)
            }
        }
        return statements
    }

    static let metadataTagMigrationStatements = [
        "CREATE TABLE track_metadata_tags (track_id INTEGER NOT NULL, tag_index INTEGER NOT NULL, tag_name TEXT NOT NULL, normalized_name TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(track_id, tag_index), FOREIGN KEY(track_id) REFERENCES tracks(id) ON DELETE CASCADE);",
        "CREATE INDEX track_metadata_tags_name_index ON track_metadata_tags(normalized_name, track_id);"
    ]

    static func install(execute: (String) throws -> Void) throws {
        try execute("BEGIN TRANSACTION;")
        do {
            for statement in creationStatements { try execute(statement) }
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }
}
