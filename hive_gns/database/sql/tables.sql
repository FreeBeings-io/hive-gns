CREATE TABLE IF NOT EXISTS gns.global_props(
    latest_block_num INTEGER,
    check_in TIMESTAMP,
    state_preloaded BOOLEAN DEFAULT false,
    state_preload_progress FLOAT DEFAULT 0,
    sync_enabled BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS gns.ops(
    id BIGSERIAL PRIMARY KEY,
    op_type_id SMALLINT NOT NULL,
    block_num INTEGER NOT NULL,
    created TIMESTAMP,
    transaction_id BYTEA,
    body JSONB
);

CREATE TABLE IF NOT EXISTS gns.module_state(
    module VARCHAR(64) PRIMARY KEY,
    module_category VARCHAR(64) NOT NULL,
    latest_gns_op_id BIGINT DEFAULT 0,
    latest_block_num BIGINT DEFAULT 0,
    check_in TIMESTAMP,
    enabled BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS gns.module_hooks(
    module VARCHAR(64) NOT NULL REFERENCES gns.module_state(module),
    notif_name VARCHAR(128) NOT NULL,
    notif_code VARCHAR(3) NOT NULL,
    description VARCHAR(500) NOT NULL,
    funct VARCHAR(128) NOT NULL,
    op_id SMALLINT NOT NULL,
    notif_filter VARCHAR(500) NOT NULL,
    prefs JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS gns.accounts(
    account VARCHAR(16) PRIMARY KEY,
    last_reads JSONB DEFAULT FORMAT('{"all": "%s"}', timezone('UTC', now()) - '30 days'::interval)::jsonb,
    prefs JSONB DEFAULT '{}'::jsonb,
    prefs_updated TIMESTAMP
);

CREATE TABLE IF NOT EXISTS gns.account_notifs(
    id BIGSERIAL PRIMARY KEY,
    trx_id BYTEA,
    account VARCHAR(16) NOT NULL REFERENCES gns.accounts(account),
    module_name VARCHAR(64) NOT NULL REFERENCES gns.module_state(module),
    notif_code VARCHAR(3) NOT NULL,
    created TIMESTAMP NOT NULL,
    remark VARCHAR(500) NOT NULL,
    payload JSONB NOT NULL,
    link VARCHAR(500),
    verified BOOLEAN DEFAULT NULL
);

CREATE INDEX IF NOT EXISTS idx_gns_acc_notifs_acc
    ON gns.account_notifs (account);

CREATE INDEX IF NOT EXISTS idx_gns_acc_notifs_module
    ON gns.account_notifs (module_name);

CREATE INDEX IF NOT EXISTS idx_gns_acc_notifs_notif_code
    ON gns.account_notifs (notif_code);

