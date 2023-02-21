CREATE OR REPLACE PROCEDURE gns.load_state(_first_block INTEGER, _last_block INTEGER)
    LANGUAGE plpgsql
    AS $$
        DECLARE
            temprow RECORD;
            _hive_opid BIGINT;
            _block_num INTEGER;
            _block_timestamp TIMESTAMP;
            _hive_op_type_id SMALLINT;
            _transaction_id VARCHAR(40);
            _body JSON;
            _hash BYTEA;
            _new_id BIGINT;
            _first_block INTEGER;
            _last_block INTEGER;
            _preloaded BOOLEAN;
        BEGIN
            SELECT state_preloaded INTO _preloaded FROM gns.global_props;
            IF _preloaded = false THEN
                FOR temprow IN
                    SELECT
                        gnsov.id AS hive_opid,
                        gnsov.op_type_id,
                        gnsov.block_num,
                        gnsov.timestamp,
                        gnsov.trx_in_block,
                        gnsov.body,
                        gnstv.trx_hash
                    FROM hive.operations_view gnsov
                    LEFT JOIN hive.transactions_view gnstv
                        ON gnstv.block_num = gnsov.block_num
                        AND gnstv.trx_in_block = gnsov.trx_in_block
                    WHERE gnsov.block_num >= _first_block
                        AND gnsov.block_num <= _last_block
                        AND gnsov.op_type_id = 18
                        AND gnsov.body::varchar::json->'value'->>'id' = 'gns'
                    ORDER BY gnsov.block_num, trx_in_block, gnsov.id
                LOOP
                    _hive_opid := temprow.hive_opid;
                    _block_num := temprow.block_num;
                    _block_timestamp = temprow.timestamp;
                    _hash := temprow.trx_hash;
                    _hive_op_type_id := temprow.op_type_id;
                    _body := (temprow.body)::json;
                    RAISE NOTICE '%s', _body;
                    PERFORM gns.core_gns(0, encode('\x0000000000000000000000000000000000000000','hex'), _block_timestamp, _body, 'gns');

                END LOOP;
                UPDATE gns.global_props SET state_preloaded = true;
                COMMIT;
            END IF;
        END;
    $$;