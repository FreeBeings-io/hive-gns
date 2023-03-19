CREATE OR REPLACE FUNCTION gns.process_custom_json_operation( _start_gns_op_id BIGINT, _end_gns_op_id BIGINT, _code VARCHAR(3), _func VARCHAR, _filter JSON )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            temprow RECORD;
            _filter_statements VARCHAR;

            _filter_statements := '';

            CASE
                WHEN _filter->'id' IS NOT NULL THEN
                    CONCAT(_filter_statements, FORMAT('AND body->''value''->''id'' = %s', _filter->'id'));
            END CASE;

            FOR temprow IN
                EXECUTE FORMAT(
                    'SELECT
                        gns_op_id, op_type_id, created,
                        transaction_id, body
                    FROM gns.ops
                    WHERE op_type_id = ANY (%I)
                    AND gns_op_id >= %I
                    AND gns_op_id <= %I
                    %s
                    ORDER BY gns_op_id ASC',
                    '_op_ids', '_start_gns_op_id', '_end_gns_op_id', _filter_statements
                )
            LOOP
                EXECUTE FORMAT('SELECT %s ($1,$2,$3,$4,$5);', _funct)
                USING temprow.gns_op_id, temprow.transaction_id, temprow.created, temprow.body, _code;
            END LOOP;
        BEGIN
            
        
        END;
    $function$;
