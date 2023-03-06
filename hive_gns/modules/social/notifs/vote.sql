CREATE OR REPLACE FUNCTION gns.core_vote( _gns_op_id BIGINT, _trx_id BYTEA, _created TIMESTAMP, _body JSON, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _req_auths VARCHAR(16)[];
            _voter VARCHAR(16);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _pending_payout JSON;
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
            --_pending_payout := _body->'value'->'pending_payout';

            _weight := _body->'value'->>'weight';
            -- RAISE NOTICE 'weight: %', _weight;
            _tot_weight := _body->'value'->>'total_vote_weight';
            -- RAISE NOTICE 'tot_weight: %', _tot_weight;
            _amount := _body->'value'->'pending_payout'->>'amount';
            -- RAISE NOTICE 'amount: %', _amount;

            IF _weight = 0 OR _tot_weight = 0 OR _amount = 0 THEN
                _value = 0;
            ELSE
                _value := (( _weight::float / _tot_weight::float) * _amount::float)::float / 1000;
            END IF;
            -- RAISE NOTICE 'value: % \n', _value;

            -- check acount
            INSERT INTO gns.accounts (account)
            SELECT _author
            WHERE NOT EXISTS (SELECT * FROM gns.accounts WHERE account = _author);

            -- check if subscribed
            _sub := gns.check_user_filter(_author, 'social', _notif_code);

            IF _sub = true AND _value > 0.01 THEN

                _remark := FORMAT('%s voted on your post ($%s)', _voter, _value);
                _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                -- make notification entry
                INSERT INTO gns.account_notifs (gns_op_id, trx_id, account, module_name, notif_code, created, remark, payload, verified, link)
                VALUES (_gns_op_id, _trx_id, _author, 'social', _notif_code, _created, _remark, _body, true, _link);
            END IF;
        EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE E'Got exception:
                SQLSTATE: % 
                SQLERRM: %
                DATA: %', SQLSTATE, SQLERRM, _body;
        END;
        $function$;