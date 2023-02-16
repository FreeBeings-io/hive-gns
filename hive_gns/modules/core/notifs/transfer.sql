CREATE OR REPLACE FUNCTION gns.core_transfer( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
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
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            -- transfer_operation
            _from := _body->'value'->>'from';
            _to := _body->'value'->>'to';
            _nai := (_body->'value'->>'amount')::json->>'nai';
            _memo := _body->'value'->>'memo';

            -- TODO: user prefs filtering

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

            -- check if subscribed
            _sub := gns.check_user_filter(_to, 'core', _notif_code);

            IF _sub = true THEN

                _remark := FORMAT('you have received %s %s from %s', _amount, _currency, _from);
                _link := FORMAT('https://hive.blog/@%s', _from);

                -- check acount
                INSERT INTO gns.accounts (account)
                SELECT _to
                WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _to);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _to, 'core', _notif_code, _created, _remark, _body, true, _link);
            END IF;

        END;
        $function$;