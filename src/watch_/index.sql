create table if not exists watch_.payload (
    id regtype   -- type of payload
        not null
        primary key
);

create table if not exists watch_.watcher (
    id text
        default md5(uuid_generate_v4()::text)
        primary key,

    payload_t regtype   -- payload-type
        references watch_.payload(id)
        on delete cascade,

    match_f regprocedure, -- match_f(ctx, payload)

    context_t regtype,    -- optional context
    context jsonb
);
