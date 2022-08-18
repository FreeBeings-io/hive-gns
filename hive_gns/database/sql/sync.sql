
CREATE OR REPLACE PROCEDURE gns.sync_main(_app_context VARCHAR)
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            _module_schema VARCHAR;
            _done BOOLEAN;

            _batch_size INTEGER := 100000;
            _op_ids SMALLINT[];
            _head_haf_block_num INTEGER;
            _global_start_block INTEGER;
            _start_hive_opid BIGINT;
            _latest_hive_opid BIGINT;
            _start BIGINT;
            _end BIGINT;
            _last_processed_block INTEGER;
            _last_processed_block_time TIMESTAMP;
        BEGIN
            _head_haf_block_num := gns.get_haf_head_block();
            _global_start_block := _head_haf_block_num - (1 * 24 * 60 * 20);
            _start_hive_opid := gns.get_hive_op_id_from_block(_global_start_block); -- 30 days blocks
            SELECT COALESCE(MAX(hive_op_id),_start_hive_opid) INTO _latest_hive_opid FROM gns.ops;


            WHILE gns.global_sync_enabled() LOOP

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
                    WHERE ov.id > _latest_hive_opid
                    AND ov.id <= (_latest_hive_opid + _batch_size)
                    ORDER BY ov.id
                LOOP
                    BEGIN
                        INSERT INTO gns.ops(
                            hive_op_id, op_type_id, block_num, created, transaction_id, body)
                        VALUES (
                            temprow.id, temprow.op_type_id, temprow.block_num,
                            temprow.timestamp, temprow.trx_hash, temprow.body);
                        _last_processed_block := temprow.block_num;
                        _last_processed_block_time := temprow.timestamp;
                    EXCEPTION WHEN OTHERS THEN
                        -- missing in ops table
                        RAISE NOTICE E'Got exception:
                        SQLSTATE: % 
                        SQLERRM: %', SQLSTATE, SQLERRM;
                    END;
                END LOOP;
                -- save done as run end
                UPDATE gns.global_props SET check_in = NOW(), latest_block_num = _last_processed_block, latest_block_time = _last_processed_block_time;
                COMMIT;
                SELECT MAX(hive_op_id) INTO _latest_hive_opid FROM gns.ops;

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
                    _last_block_time := temprow.created;
                    _last_block := temprow.block_num;
                    _last_op := temprow.id;
                END LOOP;
                -- save done as run end
                
                UPDATE gns.module_state SET check_in = NOW() WHERE module = _module_name;
                UPDATE gns.module_state SET latest_gns_op_id = COALESCE(_last_op, _latest_gns_op) WHERE module = _module_name;
                UPDATE gns.module_state SET latest_block_num = _last_block WHERE module = _module_name;
                UPDATE gns.module_state SET latest_block_time = _last_block_time WHERE module = _module_name;
                COMMIT;
            END LOOP;
        END;
    $$;