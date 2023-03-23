CREATE OR REPLACE FUNCTION gns.core_author_reward( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _hbd_payout DOUBLE PRECISION;
            _hive_payout DOUBLE PRECISION;
            _vesting_payout DOUBLE PRECISION;

            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';

            -- check author acount
            PERFORM gns.check_account(_author);

            -- check if subscribed
            _sub := gns.check_user_filter(_author, _module, _notif_code);

            IF _sub = true THEN

                -- calculate HBD, HIVE and VESTS values
                _hbd_payout := ((_body->'value'->>'hbd_payout')::jsonb->>'amount')::float / 1000;
                _hive_payout := ((_body->'value'->>'hive_payout')::jsonb->>'amount')::float / 1000;
                _vesting_payout := ((_body->'value'->>'vesting_payout')::jsonb->>'amount')::float / 1000000;

                _remark := FORMAT('You received a reward for your post. %s HBD, %s HIVE, %s VESTS', _hbd_payout, _hive_payout, _vesting_payout);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _author, _module, _notif_code, _created, _remark, _body, _link, true);

            END IF;

            -- RAISE NOTICE 'value: % \n', _value;

        
        END;
        $function$;