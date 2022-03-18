create table if not exists watch_.payload (
    id regtype   -- type of payload
        not null
        primary key,

    rebuilt_tz timestamp with time zone, -- when matching functions are rebuilt

    watcher_tz timestamp with time zone  -- last watcher updated
                                         -- cached get_watcher can be used
                                         -- if rebuilt_tz >= watcher_tz
                                         -- else use eval_watcher

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
