
CREATE OR REPLACE PROCEDURE gns.sync_main(_global_start_block INTEGER)
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            tempnotif RECORD;
            tempmodule RECORD;
            _module_schema VARCHAR;
            _enabled_modules VARCHAR[];
            _module_hooks JSONB[];

            _last_block_timestamp TIMESTAMP;
            _head_haf_block_num INTEGER;
            _latest_block_num INTEGER;
            _first_block INTEGER;
            _last_block INTEGER;
            _step INTEGER;

            _begin INTEGER;
            _target INTEGER;
        BEGIN
            _step := 200;
            RAISE NOTICE 'Global start block: %s', _global_start_block;
            SELECT latest_block_num INTO _latest_block_num FROM gns.global_props;
            
            -- load enabled modules
            FOR tempmodule IN
                SELECT module FROM gns.module_state WHERE enabled = true
            LOOP
                _enabled_modules := array_append(_enabled_modules, tempmodule.module);
            END LOOP;

            FOR tempnotif IN
                SELECT * FROM gns.module_hooks
                WHERE module = ANY (_enabled_modules)
            LOOP
                _module_hooks := array_append(_module_hooks, jsonb_build_object('module', tempnotif.module, 'funct', tempnotif.funct, 'notif_code', tempnotif.notif_code, 'op_id', tempnotif.op_id));
            END LOOP;


            --decide which block to start at initially
            IF _latest_block_num IS NULL THEN
                _begin := _global_start_block;
            ELSE
                _begin := _latest_block_num;
            END IF;

            -- begin main sync loop
            WHILE true LOOP
                IF gns.global_sync_enabled() = true THEN
                    _target := hive.app_get_irreversible_block();
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
                                    ov.body::varchar::jsonb
                                FROM hive.operations_view ov
                                LEFT JOIN hive.transactions_view tv
                                    ON tv.block_num = ov.block_num
                                    AND tv.trx_in_block = ov.trx_in_block
                                WHERE ov.block_num >= _first_block
                                    AND ov.block_num <= _last_block
                                ORDER BY ov.block_num, ov.id
                            LOOP
                                -- process operation
                                PERFORM gns.process_operation(temprow, _module_hooks);
                                _last_block_timestamp := temprow.timestamp;
                            END LOOP;
                            RAISE NOTICE 'Block range: <%, %> processed successfully.', _first_block, _last_block;
                            -- prune old data
                            PERFORM gns.prune_gns();
                            -- update global props and save
                            UPDATE gns.global_props SET check_in = NOW(), latest_block_num = _last_block, latest_block_time = _last_block_timestamp;
                            COMMIT;
                        END LOOP;
                        _begin := _target +1;
                    ELSE
                        RAISE NOTICE 'begin: %   target: %', _begin, _target;
                        PERFORM pg_sleep(1);
                    END IF;
                ELSE
                    PERFORM pg_sleep(2);
                END IF;
            END LOOP;
        END;
    $$;

CREATE OR REPLACE FUNCTION gns.process_operation( _temprow RECORD, _module_hooks JSONB[] )
    RETURNS VOID
    LANGUAGE plpgsql
    AS $$
        DECLARE
            tempnotif JSONB;
            _module_schema VARCHAR;
        BEGIN
            FOREACH tempnotif IN ARRAY _module_hooks
            LOOP
                IF (tempnotif->>'op_id')::smallint = _temprow.op_type_id THEN
                    IF gns.check_op_filter(_temprow.op_type_id, _temprow.body, tempnotif->>'notif_filter') THEN
                        EXECUTE FORMAT('SELECT %s ($1,$2,$3,$4,$5)', tempnotif->>'funct')
                            USING _temprow.trx_hash, _temprow.timestamp, _temprow.body, tempnotif->>'module', tempnotif->>'notif_code';
                    END IF;
                END IF;
            END LOOP;
        END;
    $$;
