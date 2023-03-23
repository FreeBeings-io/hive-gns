CREATE OR REPLACE FUNCTION gns.core_comment( _trx_id BYTEA, _created TIMESTAMP, _body JSONB, _module VARCHAR, _notif_code VARCHAR(3) )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE AS $function$
        DECLARE
            _parent_author VARCHAR(16);
            _parent_permlink VARCHAR(500);
            _author VARCHAR(16);
            _permlink VARCHAR(500);
            _title VARCHAR;
            _remark VARCHAR(500);
            _sub BOOLEAN;
            _link VARCHAR(500);

        BEGIN
            _parent_author := _body->'value'->>'parent_author';
            _parent_permlink := _body->'value'->>'parent_permlink';
            _author := _body->'value'->>'author';
            _permlink := _body->'value'->>'permlink';

            IF length(_parent_author) > 0 AND length(_parent_permlink) > 0 THEN
                -- check parent_author acount
                PERFORM gns.check_account(_parent_author);
                -- check author acount
                PERFORM gns.check_account(_author);

                -- check if subscribed
                _sub := gns.check_user_filter(_parent_author, _module, _notif_code);

                IF _sub = true THEN

                    _remark := FORMAT('%s commented on your post', _parent_author);
                    _link := FORMAT('https://hive.blog/@%s/%s', _author, _permlink);

                    -- make notification entry
                    PERFORM gns.save_notif(_trx_id, _author, _module, _notif_code, _created, _remark, _body, _link, true);
                END IF;
            END IF;
        
        END;
        $function$;