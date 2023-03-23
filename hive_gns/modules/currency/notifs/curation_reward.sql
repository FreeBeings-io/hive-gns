CREATE OR REPLACE FUNCTION gns.core_curation_reward( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _curator VARCHAR(16);
            _reward DOUBLE PRECISION;
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);
        BEGIN
            _curator := _body->'value'->>'curator';
            -- check curator acount
            PERFORM gns.check_account(_curator);
            -- check if subscribed
            _sub := gns.check_user_filter(_curator, _module, _notif_code);
            IF _sub = true THEN
                _reward := ((_body->'value'->>'reward')::jsonb->>'amount')::float / 1000000;
                _remark := FORMAT('You received a curation reward of %s VESTS', _reward);
                _link := FORMAT('https://hive.blog/@%s/%s', _body->'value'->>'comment_author', _body->'value'->>'comment_permlink');
                -- make notification entry
                PERFORM gns.save_notif(_trx_id, _curator, _module, _notif_code, _created, _remark, _body, _link, true);
            END IF;
        END;
        $function$;