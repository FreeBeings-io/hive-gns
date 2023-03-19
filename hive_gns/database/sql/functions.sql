
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
                RAISE NOTICE E'Got exception get_internal_func:
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

CREATE OR REPLACE FUNCTION gns.prune_haf()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            DELETE FROM hive.blocks
            WHERE num <= (hive.app_get_irreversible_block() - (30 * 24 * 60 * 20));
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.prune_gns()
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            DELETE FROM gns.account_notifs
            WHERE created <= NOW() - INTERVAL '30 days';
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

CREATE OR REPLACE FUNCTION gns.is_sync_running(app_desc VARCHAR)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
        BEGIN
            RETURN (
                SELECT EXISTS (
                    SELECT * FROM pg_stat_activity
                    WHERE application_name = app_desc
                )
            );
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.terminate_main_sync(app_desc VARCHAR)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _pid INTEGER;
        BEGIN
            SELECT pid INTO _pid FROM pg_stat_activity
                WHERE application_name = app_desc;
            IF _pid IS NOT NULL THEN
                PERFORM pg_cancel_backend(_pid);
            END IF;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.app_get_all_modules_data()
    RETURNS JSONB
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _result JSONB;
            _module VARCHAR;
            _description VARCHAR;
            _category VARCHAR;
        BEGIN
            _result := jsonb_build_object();
            FOR _module IN SELECT DISTINCT module
            FROM gns.module_hooks
            LOOP
                _result := _result || jsonb_build_object(_module, (SELECT json_agg(mod.details) FROM (
                    SELECT json_build_array(gms.module_category, gmh.description, gmh.module, gmh.notif_code) details
                    FROM gns.module_hooks gmh
                    JOIN gns.module_state gms ON gms.module = gmh.module
                    WHERE gmh.module=_module) mod));
            END LOOP;
            RETURN _result;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.check_account(_acc VARCHAR(16))
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _exists BOOLEAN;
        BEGIN
            -- if acc is null then raise exception
            IF _acc IS NULL THEN
                RAISE EXCEPTION 'Account is null';
            END IF;
            SELECT EXISTS (SELECT * FROM gns.accounts WHERE account = _acc) INTO _exists;
            IF NOT _exists THEN
                INSERT INTO gns.accounts (account)
                VALUES (_acc);
            END IF;
        END;
    $function$;

CREATE OR REPLACE FUNCTION gns.save_notif(_trx_id BYTEA, _acc VARCHAR, _module VARCHAR, _notif_code VARCHAR, _created TIMESTAMP, _remark VARCHAR, _payload JSON, _link VARCHAR, _verified BOOLEAN)
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        BEGIN
            -- insert notification
            INSERT INTO gns.account_notifs (trx_id, account, module_name, notif_code, created, remark, payload, link, verified)
            VALUES (_trx_id, _acc, _module, _notif_code, _created, _remark, _payload, _link, _verified);
        END;
    $function$;

