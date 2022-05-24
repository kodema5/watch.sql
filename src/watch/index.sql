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
\ir to_query_text.sql

-- uses dynamic sql to get matching watchers
--
\ir eval_watcher.sql

-- for debugging
--
\ir is_match.sql

-- the matching functions can be cached for for performance
-- get_watcher uses cached_match_f
--
\ir is_cached.sql
\ir reset_cached_fs.sql
\ir get_watcher.sql


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
