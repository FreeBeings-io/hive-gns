CREATE OR REPLACE FUNCTION gns.core_deleg( _trx_id BYTEA, _created TIMESTAMP, _body JSON, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _delegator VARCHAR(16);
            _delegatee VARCHAR(16);
            _amount BIGINT;
            _vests NUMERIC;
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _delegator := _body->'value'->>'delegator';
            _delegatee := _body->'value'->>'delegatee';
            _amount := _body->'value'->'vesting_shares'->>'amount';
            _vests := round((_amount::numeric)/1000000, 6);

            -- check acount
            PERFORM gns.check_account(_delegatee);

            -- check if subscribed
            _sub := gns.check_user_filter(_delegatee, _module, _notif_code);

            IF _sub = true THEN

                IF _amount > 0 THEN
                    _remark := FORMAT('%s is now delegating %s VESTS to you', _delegator, _vests);
                ELSE
                    _remark := FORMAT('%s removed their vesting delegation', _delegator);
                END IF;
                _link := FORMAT('https://hive.blog/@%s', _delegator);

                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _delegatee, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;
        END;
        $function$;