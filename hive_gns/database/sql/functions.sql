
CREATE OR REPLACE FUNCTION gns.get_internal_func( _op_type_id SMALLINT)
    RETURNS VARCHAR
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            IF _op_type_id = 18 THEN
                RETURN 'process_custom_json_operation';
            ELSIF _op_type_id = 2 THEN
                RETURN 'process_transfer_operation';
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %', SQLSTATE, SQLERRM;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.get_haf_head_block()
    RETURNS INTEGER
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (SELECT MAX(block_num) FROM hive.operations_view);
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.get_haf_head_hive_opid()
    RETURNS BIGINT
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (SELECT id FROM hive.operations_view ORDER BY id DESC LIMIT 1);
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.get_hive_op_id_from_block(_block_num INTEGER)
    RETURNS BIGINT
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (SELECT id FROM hive.operations_view WHERE block_num = _block_num ORDER BY id ASC LIMIT 1);
        END;
    $function$;

    

CREATE OR REPLACE FUNCTION gns.global_sync_enabled()
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (SELECT sync_enabled FROM gns.global_props LIMIT 1);
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.prune()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            DELETE FROM gns.ops
            WHERE created <= NOW() - INTERVAL '30 DAYS';
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.module_enabled( _module VARCHAR)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (SELECT enabled FROM gns.module_state WHERE module=_module);
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.module_running( _module VARCHAR)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (
                SELECT EXISTS (
                    SELECT pid FROM pg_stat_activity
                    WHERE query = FORMAT('CALL gns.sync_module( ''%s'' );', _module)
                )
            );
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.module_long_running( _module VARCHAR)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            RETURN (
                SELECT EXISTS (
                    SELECT * FROM gns.module_state
                    WHERE module = _module
                    AND check_in >= NOW() - INTERVAL '1 min'
                )
            );
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.module_terminate_sync( _module VARCHAR)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _pid INTEGER;
        BEGIN
            SELECT pid INTO _pid FROM pg_stat_activity
                WHERE query = FORMAT('CALL gns.sync_module( ''%s'' );', _module);
            IF _pid IS NOT NULL THEN
                SELECT pg_cancel_backend(_pid);
            END IF;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.terminate_main_sync()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _pid INTEGER;
        BEGIN
            SELECT pid INTO _pid FROM pg_stat_activity
                WHERE query = 'CALL gns.sync_main();';
            IF _pid IS NOT NULL THEN
                SELECT pg_cancel_backend(_pid);
            END IF;
        END;
    $function$;
