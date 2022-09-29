
CREATE OR REPLACE PROCEDURE gns.sync_main()
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            tempmodule RECORD;
            _module_schema VARCHAR;
            _to_attach BOOLEAN;

            _global_start_block INTEGER;
            _head_haf_block_num INTEGER;
            _latest_block_num INTEGER;
            _next_block_range hive.blocks_range;
            _first_block INTEGER;
            _last_block INTEGER;
            _step INTEGER;
        BEGIN
            _step := 1000;
            _head_haf_block_num := gns.get_haf_head_block();
            RAISE NOTICE 'Found head haf block num: %s', _head_haf_block_num;
            _global_start_block := _head_haf_block_num - (1 * 24 * 60 * 20);
            RAISE NOTICE 'Global start block: %s', _head_haf_block_num;
            SELECT latest_block_num INTO _latest_block_num FROM gns.global_props;

            WHILE gns.global_sync_enabled() LOOP
                _to_attach := false;
                _next_block_range := hive.app_next_block('gns');

                IF _next_block_range IS NULL THEN
                    RAISE WARNING 'Waiting for next block...';
                ELSE
                    -- determine if massive sync is needed
                    IF _next_block_range.last_block - _next_block_range.first_block > 0 THEN
                        -- detach context
                        PERFORM hive.app_context_detach('gns');
                        RAISE NOTICE 'Context detached.';
                        _to_attach := true;
                        COMMIT;
                    END IF;
                    RAISE NOTICE 'New block range: <%,%>', _next_block_range.first_block, _next_block_range.last_block;
                    FOR _first_block IN _next_block_range.first_block .. _next_block_range.last_block BY _step LOOP
                        _last_block := _first_block + _step - 1;

                        IF _last_block > _next_block_range.last_block THEN --- in case the _step is larger than range length
                            _last_block := _next_block_range.last_block;
                        END IF;

                        RAISE NOTICE 'Attempting to process a block range: <%, %>', _first_block, _last_block;
                        FOR temprow IN
                            SELECT
                                ov.id,
                                ov.op_type_id,
                                ov.block_num,
                                ov.timestamp,
                                ov.trx_in_block,
                                tv.trx_hash,
                                ov.body::json
                            FROM hive.gns_operations_view ov
                            LEFT JOIN hive.gns_transactions_view tv
                                ON tv.block_num = ov.block_num
                                AND tv.trx_in_block = ov.trx_in_block
                            WHERE ov.block_num >= _first_block
                                AND ov.block_num <= _last_block
                            ORDER BY ov.block_num, ov.id
                        LOOP
                            INSERT INTO gns.ops(
                                op_type_id, block_num, created, transaction_id, body)
                            VALUES (
                                temprow.op_type_id, temprow.block_num,
                                temprow.timestamp, temprow.trx_hash, temprow.body);
                        END LOOP;
                        RAISE NOTICE 'Block range: <%, %> processed successfully.', _first_block, _last_block;
                        -- update global props and save
                        UPDATE gns.global_props SET check_in = NOW(), latest_block_num = _last_block;
                        COMMIT;
                        -- loop through all module names and run sync
                        FOR tempmodule IN
                            SELECT * FROM gns.module_state 
                        LOOP
                            IF tempmodule.enabled = true THEN
                                RAISE NOTICE 'Attempting to sync module: %', tempmodule.module;
                                CALL gns.sync_module(tempmodule.module);
                                RAISE NOTICE 'Module synced: %', tempmodule.module;
                            END IF;
                        END LOOP;
                        COMMIT;
                    END LOOP;
                    IF _to_attach = true THEN
                        -- attach context
                        PERFORM hive.app_context_attach('gns', _last_block);
                        RAISE NOTICE 'Context attached.';
                        COMMIT;
                    END IF;
                END IF;
            END LOOP;
        END;
    $$;

CREATE OR REPLACE PROCEDURE gns.sync_module(_module_name VARCHAR(64) )
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            _done BOOLEAN;
            _last_block_time TIMESTAMP;
            _last_op BIGINT;
            _last_block INTEGER;
            _op_ids SMALLINT[];
            _latest_gns_op BIGINT;
            _batch_size INTEGER := 100000;
        BEGIN
            SELECT ARRAY (SELECT op_id FROM gns.module_hooks WHERE module = _module_name) INTO _op_ids;
            SELECT latest_gns_op_id INTO _latest_gns_op FROM gns.module_state WHERE module = _module_name;

            FOR temprow IN
                SELECT
                    id,
                    op_type_id,
                    block_num,
                    created,
                    transaction_id,
                    body::json
                FROM gns.ops
                WHERE id > _latest_gns_op
                    AND id <= (_latest_gns_op + _batch_size)
                    AND op_type_id = ANY (_op_ids)
                ORDER BY id
            LOOP
                FOR tempnotif IN 
                    SELECT DISTINCT ON (funct) * FROM gns.module_hooks
                    WHERE module = _module_name
                    AND op_id = temprow.op_type_id
                LOOP
                    IF gns.check_op_filter(temprow.op_type_id, temprow.body, tempnotif.notif_filter) THEN
                        EXECUTE FORMAT('SELECT %s ($1,$2,$3,$4,$5)', tempnotif.funct)
                            USING temprow.id, temprow.transaction_id, temprow.created, temprow.body, tempnotif.notif_code;
                    END IF;
                END LOOP;
                _last_block := temprow.block_num;
                _last_op := temprow.id;
            END LOOP;
            -- save done as run end
            
            UPDATE gns.module_state SET check_in = NOW() WHERE module = _module_name;
            UPDATE gns.module_state SET latest_gns_op_id = COALESCE(_last_op, _latest_gns_op) WHERE module = _module_name;
            UPDATE gns.module_state SET latest_block_num = _last_block WHERE module = _module_name;
        END;
    $$;