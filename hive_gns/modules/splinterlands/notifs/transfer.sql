CREATE OR REPLACE FUNCTION gns.sm_token_transfer( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
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
            _link VARCHAR(500);
        BEGIN

            -- check acount


            IF _sub = true THEN
                _op_id := _body->'value'->>'id';

                IF _op_id = 'sm_token_transfer' THEN
                    -- normal transfer_operation
                    _req_auths := ARRAY(SELECT jsonb_array_elements_text((_body->'value'->'required_auths')));
                    _from := _req_auths[1];
                    _to := (_body->'value'->>'json')::jsonb->>'to';
                    _qty := (_body->'value'->>'json')::jsonb->>'qty';
                    _memo := (_body->'value'->>'json')::jsonb->>'memo';
                    _token := (_body->'value'->>'json')::jsonb->>'token';
                    
                    IF _to IS NULL THEN
                        RETURN;
                    END IF;

                    -- check account
                    PERFORM gns.check_account(_to);
                    -- check if subscribed
                    _sub := gns.check_user_filter(_to, _module, _notif_code);

                    _remark := FORMAT('you have received %s %s from %s', _qty, _token, _from);
                    _link := FORMAT('https://hive.blog/@%s', _from);

                    -- make notification entry
                    PERFORM gns.save_notif(_trx_id, _to, _module, _notif_code, _created, _remark, _body, _link);
                END IF;
            END IF;
        
        END;
        $function$;