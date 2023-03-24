CREATE OR REPLACE PROCEDURE gns.load_state(_first_block INTEGER, _last_block INTEGER)
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            _module VARCHAR := 'core';
            _notif_code VARCHAR := 'gns';
            _hive_opid BIGINT;
            _block_num INTEGER;
            _block_timestamp TIMESTAMP;
            _hive_op_type_id SMALLINT;
            _transaction_id VARCHAR(40);
            _body JSONB;
            _hash BYTEA;
            _new_id BIGINT;
            _preloaded BOOLEAN;
            _target INTEGER := 0;
            _last_processed_block INTEGER;
            _range INTEGER;
        BEGIN
            SELECT state_preloaded INTO _preloaded FROM gns.global_props;
            RAISE NOTICE 'state_preloaded: %', _preloaded;
            -- TODO: check if any preivous attempt was interrupted and resume from last processed block
            IF _preloaded = false THEN
                RAISE NOTICE 'Preloading state from block % to %', _first_block, _last_block;
                -- process in batches of 1000 blocks
                _last_processed_block := _first_block;
                _range := _last_block - _first_block;
                WHILE _last_processed_block < _last_block LOOP
                    _target := _last_processed_block + 10000;
                    IF _target > _last_block THEN
                        _target := _last_block;
                    END IF;
                    RAISE NOTICE 'Processing blocks % to %', _last_processed_block, _target;
                    FOR temprow IN
                        SELECT
                            gnsov.id AS hive_opid,
                            gnsov.op_type_id,
                            gnsov.block_num,
                            gnsov.timestamp,
                            gnsov.trx_in_block,
                            gnsov.body::varchar::jsonb,
                            gnstv.trx_hash
                        FROM hive.operations_view gnsov
                        LEFT JOIN hive.transactions_view gnstv
                            ON gnstv.block_num = gnsov.block_num
                            AND gnstv.trx_in_block = gnsov.trx_in_block
                        WHERE gnsov.block_num >= _last_processed_block
                            AND gnsov.block_num <= _target
                            AND gnsov.op_type_id = 18
                            AND gnsov.body::varchar::jsonb->'value'->>'id' = 'gns'
                        ORDER BY gnsov.block_num, trx_in_block, gnsov.id
                    LOOP
                        _hive_opid := temprow.hive_opid;
                        _block_num := temprow.block_num;
                        _block_timestamp = temprow.timestamp;
                        _hash := temprow.trx_hash;
                        _hive_op_type_id := temprow.op_type_id;
                        _body := (temprow.body)::jsonb;
                        PERFORM gns.core_gns(_hash, _block_timestamp, _body, _module, _notif_code);
                    END LOOP;
                    _last_processed_block := _target + 1;
                    -- update state_preload_progress with percentage of range processed
                    UPDATE gns.global_props SET state_preload_progress = ((_last_processed_block::float - _first_block::float) / _range::float)::float * 100;
                    COMMIT;
                END LOOP;
                UPDATE gns.global_props SET state_preloaded = true;
                COMMIT;
            END IF;
            UPDATE gns.global_props SET sync_enabled = true;
            COMMIT;
        END;
    $$;