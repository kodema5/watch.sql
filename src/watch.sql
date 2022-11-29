\if :{?watch_sql}
\else
\set watch_sql true
--
-- given a payload, find matching watchers
--

\if :local
drop schema if exists _watch cascade;
\endif
create schema if not exists _watch;
drop schema if exists watch cascade;
create schema watch;

create table if not exists _watch.payload (
    id text -- type of payload
        check (to_regtype(id) is not null)
        not null
        primary key,

    rebuilt_tz timestamp with time zone, -- when matching functions are rebuilt

    watcher_tz timestamp with time zone  -- last watcher updated
                                         -- cached get_watcher can be used
                                         -- if rebuilt_tz >= watcher_tz
                                         -- else use eval_watcher

);


create table if not exists _watch.watcher (
    id text
        default md5(gen_random_uuid()::text)
        primary key,

    payload_t text   -- payload-type
        check (to_regtype(payload_t) is not null)
        references _watch.payload(id)
        on delete cascade,

    match_f text -- match_f(ctx, payload)
        check (to_regprocedure(match_f) is not null),

    context_t text -- optional context
        check (context_t is null or to_regtype(context_t) is not null),
    context jsonb
);

-- watchers
-- finds matching watchers by executing:
--      select watch_id, match_f(context, payload)
--      union
--      select watch_id, match_f(context, payload)
--      union
--      ...

-- these functions are then cached in watch.cached_match_f(payload_t)


-- for building query-texts for a match
--
\ir watch/to_query_text.sql

-- uses dynamic sql to get matching watchers
--
\ir watch/eval_watcher.sql

-- for debugging
--
\ir watch/is_match.sql

-- the matching functions can be cached for for performance
-- get_watcher uses cached_match_f
--
\ir watch/is_cached.sql
\ir watch/cache_fs.sql
\ir watch/get_watcher.sql


-- given a payload, returns relevant watchera
--
create function watch.get(
    p anyelement
)
    returns setof _watch.watcher
    language sql
    security definer
    stable
as $$
    -- for those yet cached
    select t
        from watch.eval_watcher(p) t
        where not watch.is_cached(pg_typeof(p))
    union
    -- for those cached
    select t
        from watch.get_watcher(p) t
        where watch.is_cached(pg_typeof(p))
$$;


\ir watch/tests/unit.sql
\ir watch/tests/price_tick.sql

\endif