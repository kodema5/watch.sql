-- for building query-texts for a match
--
\ir to_query_text.sql

-- uses dynamic sql to get matching watchers
--
\ir eval_matcher.sql

-- for debugging
--
\ir is_match.sql


-- the matching functions can be cached for for performance
-- get_watcher uses cached_match_f
--
\ir is_cached.sql
\ir reset_cached_fs.sql
\ir get_watcher.sql

create function watch.get(
    p anyelement
)
    returns _watch.watcher
    language sql
    security definer
    stable
as $$
    select t
        from watch.eval_watcher(p) t
        where not watch.is_cached(pg_typeof(p))
    union
    select t
        from watch.get_watcher(p) t
        where watch.is_cached(pg_typeof(p))
$$;

