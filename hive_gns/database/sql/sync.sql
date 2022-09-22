
CREATE OR REPLACE PROCEDURE gns.sync_main()
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            _module_schema VARCHAR;

            _global_start_block INTEGER;
            _head_haf_block_num INTEGER;
            _latest_block_num INTEGER;
            _first_block INTEGER;
            _last_block INTEGER;
            _step INTEGER;

            _begin INTEGER;
            _target INTEGER;
        BEGIN
            _step := 10000;
            _head_haf_block_num := gns.get_haf_head_block();
            RAISE NOTICE 'Found head haf block num: %s', _head_haf_block_num;
            _global_start_block := _head_haf_block_num - (1 * 24 * 60 * 20);
            RAISE NOTICE 'Global start block: %s', _head_haf_block_num;
            SELECT latest_block_num INTO _latest_block_num FROM gns.global_props;

            --decide which block to start at initially
            IF _latest_block_num IS NULL THEN
                _begin := _global_start_block;
            ELSE
                _begin := _latest_block_num;
            END IF;

            -- begin main sync loop
            WHILE gns.global_sync_enabled() LOOP
                _target := gns.get_haf_head_block();
                IF _target - _begin >= 0 THEN
                    RAISE NOTICE 'New block range: <%,%>', _begin, _target;
                    FOR _first_block IN _begin .. _target BY _step LOOP
                        _last_block := _first_block + _step - 1;

                        IF _last_block > _target THEN --- in case the _step is larger than range length
                            _last_block := _target;
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
                            FROM hive.operations_view ov
                            LEFT JOIN hive.transactions_view tv
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
                        -- update hlobal props and save
                        UPDATE gns.global_props SET check_in = NOW(), latest_block_num = _last_block;
                        COMMIT;
                    END LOOP;
                    _begin := _target +1;
                ELSE
                    RAISE NOTICE 'begin: %   target: %', _begin, _target;
                    PERFORM pg_sleep(1);
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
            _batch_size INTEGER := 10000;
        BEGIN
            WHILE gns.module_enabled(_module_name) LOOP
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
                COMMIT;
            END LOOP;
        END;
    $$;