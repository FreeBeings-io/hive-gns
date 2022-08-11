CREATE OR REPLACE FUNCTION gns.sm_token_transfer( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _from VARCHAR(16);
            _to VARCHAR(16);
            _qty DOUBLE PRECISION;
            _token VARCHAR(11);
            _memo VARCHAR(2048);
            _remark VARCHAR(500);
            _op_id VARCHAR;
            _req_auths VARCHAR(16)[];
            _sub BOOLEAN;
        BEGIN
            -- check if subscribed
            _sub := gns.account_check_notif(_to, 'core', _notif_code);

            IF _sub = true THEN
                _op_id := _body->'value'->>'id';

                IF _op_id = 'sm_token_transfer' THEN
                    -- normal transfer_operation
                    _req_auths := ARRAY(SELECT json_array_elements_text((_body->'value'->'required_auths')));
                    _from := _req_auths[1];
                    _to := (_body->'value'->>'json')::json->>'to';
                    _qty := (_body->'value'->>'json')::json->>'qty';
                    _memo := (_body->'value'->>'json')::json->>'memo';
                    _token := (_body->'value'->>'json')::json->>'token';

                    _remark := FORMAT('you have received %s %s from %s', _qty, _token, _from);

                    -- check acount
                    INSERT INTO gns.accounts (account)
                    SELECT _to
                    WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _to);

                    -- make notification entry
                    INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload)
                    VALUES (_gns_op_id, _trx_id, _to, 'splinterlands', _notif_code, _created, _remark, _body);
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %', SQLSTATE, SQLERRM;
        END;
        $function$;