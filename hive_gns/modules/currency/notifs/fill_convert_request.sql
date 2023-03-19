CREATE OR REPLACE FUNCTION gns.core_fill_convert_request( _trx_id BYTEA, _created TIMESTAMP, _body JSON, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _account VARCHAR(16);
            _amount_in FLOAT;
            _amount_out FLOAT;
            _sub BOOLEAN;
            _link VARCHAR(500);
            _remark VARCHAR(500);
        BEGIN
            _account := _body->'value'->>'owner';
            -- check account
            PERFORM gns.check_account(_account);
            -- check if subscribed
            _sub := gns.check_user_filter(_account, _module, _notif_code);
            IF _sub = true THEN
                _amount_in := ((_body->'value'->>'amount_in')::json->>'amount')::float / 1000;
                _amount_out := ((_body->'value'->>'amount_out')::json->>'amount')::float / 1000;
                IF (_body->'value'->>'amount_in')::json->>'nai' = '@@000000013' THEN
                    _remark := FORMAT('Successfully converted %s HIVE to %s HBD', _amount_in, _amount_out);
                ELSE
                    _remark := FORMAT('Successfully converted %s HBD to %s HIVE', _amount_in, _amount_out);
                END IF;
                _link := FORMAT('https://hive.blog/@%s', _account);
                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _account, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;
        END;
        $function$;
