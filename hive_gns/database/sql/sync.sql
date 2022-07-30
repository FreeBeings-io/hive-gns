-- check context

CREATE OR REPLACE PROCEDURE gns.sync_main(_module_name VARCHAR(64))
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            _app_context VARCHAR;
            _ops VARCHAR[];
            _op_ids SMALLINT[];
            _next_block_range hive.blocks_range;
            _latest_block_num INTEGER;
            _range BIGINT[];
        BEGIN
            _app_context := 'gns';

            SELECT COALESCE(MAX(block_num),0) INTO _latest_block_num FROM gns.ops;
            

            IF NOT hive.app_context_is_attached(_app_context) THEN
                PERFORM hive.app_context_attach(_app_context, _latest_block_num);
            END IF;

            WHILE gns.global_sync_enabled() LOOP
                _next_block_range := hive.app_next_block(_app_context);
                IF _next_block_range IS NULL THEN
                    RAISE WARNING 'Waiting for next block...';
                ELSE
                    RAISE NOTICE 'Attempting to process block range: <%,%>', _next_block_range.first_block, _next_block_range.last_block;
                    CALL gns.process_block_range(_module_name, _app_context, _next_block_range.first_block, _next_block_range.last_block, _ops, _op_ids);
                END IF;
            END LOOP;
            COMMIT;
        END;
    $$;

CREATE OR REPLACE PROCEDURE gns.process_block_range(_app_context VARCHAR, _start INTEGER, _end INTEGER )
    LANGUAGE plpgsql
    AS $$

        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            _module_schema VARCHAR;
            _done BOOLEAN;
            _massive BOOLEAN;
            _first_block INTEGER;
            _last_block INTEGER;
            _step INTEGER;
            _notifs VARCHAR[];
            _new_id INTEGER;
        BEGIN
            _step := 1000;
            -- determine if massive sync is needed
            IF _end - _start > 0 THEN
                -- detach context
                PERFORM hive.app_context_detach(_app_context);
                _massive := true;
            END IF;
            -- divide range
            FOR _first_block IN _start .. _end BY _step LOOP
                _last_block := _first_block + _step - 1;

                IF _last_block > _end THEN --- in case the _step is larger than range length
                    _last_block := _end;
                END IF;

                RAISE NOTICE 'Attempting to process a block range: <%, %>', _first_block, _last_block;
                -- record run start
                    -- select records and pass records to relevant functions
                FOR temprow IN
                    EXECUTE FORMAT('
                        SELECT
                            ov.id,
                            ov.op_type_id,
                            ov.block_num,
                            ov.timestamp,
                            ov.trx_in_block,
                            tv.trx_hash,
                            ov.body::json
                        FROM hive.%1$s_operations_view ov
                        LEFT JOIN hive.%1$s_transactions_view tv
                            ON tv.block_num = ov.block_num
                            AND tv.trx_in_block = ov.trx_in_block
                        WHERE ov.block_num >= $1
                            AND ov.block_num <= $2
                        ORDER BY ov.block_num, trx_in_block, ov.id;', _app_context)
                    USING _first_block, _last_block
                LOOP
                    INSERT INTO gns.ops(
                        hive_opid, op_type_id, block_num, created, transaction_id, body)
                    VALUES (
                        temprow.hive_opid, temprow.op_type_id, temprow.block_num,
                        temprow.timestamp, temprow.trx_hash, temprow.body);
                END LOOP;
                -- save done as run end
                RAISE NOTICE 'Block range: <%, %> processed successfully.', _first_block, _last_block;
                UPDATE gns.global_props SET check_in = NOW();
                COMMIT;
            END LOOP;
            IF _massive = true THEN
                -- attach context
                PERFORM hive.app_context_attach(_app_context, _last_block);
            END IF;
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
            _step INTEGER;
            _first_op INTEGER;
            _last_op INTEGER;
            _op_ids SMALLINT[];
            _start BIGINT;
            _end BIGINT;
        BEGIN
            _step := 1000;
            SELECT COALCESCE(MAX(id), 0) INTO _end FROM gns.ops;
            SELECT COALESCE(MAX(latest_gns_op_id), 0) INTO _start FROM gns.module_state WHERE module = _module_name;
            SELECT ARRAY (SELECT op_id FROM gns.module_hooks WHERE module = _module_name) INTO _op_ids;
            -- divide range
            FOR _first_op IN _start .. _end BY _step LOOP
                _last_op := _first_op + _step - 1;

                IF _last_op > _end THEN --- in case the _step is larger than range length
                    _last_op := _end;
                END IF;

                RAISE NOTICE 'Attempting to process an op range: <%, %>', _first_op, _last_op;
                -- record run start
                    -- select records and pass records to relevant functions
                FOR temprow IN
                    EXECUTE FORMAT('
                        SELECT
                            id,
                            op_type_id,
                            block_num,
                            created,
                            transaction_id,
                            body::json
                        FROM gns.ops
                        WHERE id >= $1
                            AND id <= $2
                            AND op_type_id IN $3
                        ORDER BY id;')
                    USING _first_op, _last_op, _op_ids
                LOOP
                    FOR tempnotif IN 
                        SELECT DISTINCT ON (funct) * FROM gns.module_hooks
                        WHERE module = _module_name
                        AND op_id = temprow.op_type_id
                    LOOP
                        IF gns.check_op_filter(temprow.body, tempnotif.filter) THEN
                            EXECUTE FORMAT('SELECT %s ()', tempnotif.funct)
                                USING temprow.id, temprow.trx_hash, temprow.timestamp, temprow.body, tempnotif.notif_code;
                        END IF;
                    END LOOP;
                    _last_block_time := temprow.created;
                END LOOP;
                -- save done as run end
                RAISE NOTICE 'Op range: <%, %> processed successfully.', _first_op, _last_op;
                UPDATE gns.module_state SET check_in = NOW() WHERE module = _module_name;
                UPDATE gns.module_state SET latest_gns_op_id = _last_op WHERE module = _module_name;
                UPDATE gns.module_state SET latest_block_num = _last_block WHERE module = _module_name;
                UPDATE gns.module_state SET latest_block_time = _last_block_time WHERE module = _module_name;
                COMMIT;
            END LOOP;
        END;
    $$;