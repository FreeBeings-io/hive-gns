CREATE OR REPLACE FUNCTION gns.core_transfer( _gns_op_id BIGINT, _trx_id CHAR(40), _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _from VARCHAR(16);
            _to VARCHAR(16);
            _nai VARCHAR(11);
            _amount DOUBLE PRECISION;
            _memo VARCHAR(2048);
            _currency VARCHAR(4);
            _remark VARCHAR(500);
            _read TIMESTAMP;
            _read_json JSON;
        BEGIN
            -- transfer_operation
            _from := _body->'value'->>'from';
            _to := _body->'value'->>'to';
            _nai := (_body->'value'->>'amount')::json->>'nai';
            _memo := _body->'value'->>'memo';

            IF _nai = '@@000000013' THEN
                _currency := 'HBD';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000;
            ELSIF _nai = '@@000000021' THEN
                _currency := 'HIVE';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000;
            ELSIF _nai = '@@000000037' THEN
                _currency := 'HP';
                _amount := ((_body->'value'->>'amount')::json->>'amount')::float / 1000000;
            END IF;

            _remark := FORMAT('you have received %s %s from %s', _amount, _currency, _from);

            -- check acount
            INSERT INTO gns.accounts (account)
            SELECT _to
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _to);

            -- make notification entry
            INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified)
            VALUES (_gns_op_id, _trx_id, _to, 'core', _notif_code, _created, _remark, _body, true);

        END;
        $function$;

CREATE OR REPLACE FUNCTION gns.core_gns( _gns_op_id BIGINT, _trx_id CHAR(40), _created TIMESTAMP, _body JSON, _notif_name VARCHAR(128) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _acc VARCHAR(16);
            _op_id VARCHAR;
            _payload JSON;
            _op_name VARCHAR;
            _data JSON;
        BEGIN

            IF _op_id = 'gns' THEN
                _req_auths := ARRAY(SELECT json_array_elements_text((_body->'value'->'required_auths')));
                _acc := _req_auths[1];
                _payload := (_body->'value'->>'json')::json;
                _op_name := _payload->0;
                _data := _payload->1::json;
                -- update preferences
                IF _op_name = 'prefs' THEN
                    IF _data IS NOT NULL THEN
                        -- check acount
                        INSERT INTO gns.accounts (account)
                        SELECT _acc
                        WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _acc);
                        -- update account's prefs and set prefs_updated
                        UPDATE gns.accounts SET prefs = _data, prefs_updated = _created WHERE account = _acc;
                    END IF;
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %', SQLSTATE, SQLERRM;
        END;
        $function$;