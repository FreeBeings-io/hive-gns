CREATE OR REPLACE FUNCTION gns.core_transfer( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
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
            _read_json JSONB;
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            -- transfer_operation
            _from := _body->'value'->>'from';
            _to := _body->'value'->>'to';
            _nai := (_body->'value'->>'amount')::jsonb->>'nai';
            _memo := _body->'value'->>'memo';

            -- if any above is null, skip
            IF _from IS NULL OR _to IS NULL OR _nai IS NULL THEN
                RETURN;
            END IF;

            -- TODO: user prefs filtering

            IF _nai = '@@000000013' THEN
                _currency := 'HBD';
                _amount := ((_body->'value'->>'amount')::jsonb->>'amount')::float / 1000;
            ELSIF _nai = '@@000000021' THEN
                _currency := 'HIVE';
                _amount := ((_body->'value'->>'amount')::jsonb->>'amount')::float / 1000;
            ELSIF _nai = '@@000000037' THEN
                _currency := 'HP';
                _amount := ((_body->'value'->>'amount')::jsonb->>'amount')::float / 1000000;
            END IF;

            -- check acount
            PERFORM gns.check_account(_to);

            -- check if subscribed
            _sub := gns.check_user_filter(_to, _module, _notif_code);

            IF _sub = true THEN

                _remark := FORMAT('you have received %s %s from %s', _amount, _currency, _from);
                _link := FORMAT('https://hive.blog/@%s', _from);

                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _to, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;

        END;
        $function$;