CREATE OR REPLACE FUNCTION gns.core_vote( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _voter VARCHAR(16);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _pending_payout JSONB;
            _value NUMERIC(10,2);
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

            _weight BIGINT;
            _tot_weight BIGINT;
            _amount BIGINT;
        BEGIN
            _voter := _body->'value'->>'voter';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';

            _weight := _body->'value'->>'weight';
            _tot_weight := _body->'value'->>'total_vote_weight';
            _amount := _body->'value'->'pending_payout'->>'amount';

            IF _weight = 0 OR _tot_weight = 0 OR _amount = 0 THEN
                _value = 0;
            ELSE
                _value := (( _weight::float / _tot_weight::float) * _amount::float)::float / 1000;
            END IF;

            -- check acount
            PERFORM gns.check_account(_author);

            -- check if subscribed
            _sub := gns.check_user_filter(_author, _module, _notif_code);

            IF _sub = true AND _value > 0.01 THEN

                _remark := FORMAT('%s voted on your post ($%s)', _voter, _value);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _author, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;
        
        END;
        $function$;