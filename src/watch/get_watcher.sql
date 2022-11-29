\if :{?watch_get_watcher_sql}
\else
\set watch_get_watcher_sql true


create function watch.get_watcher (
    payload anyelement,
    matched_ boolean default true
)
    returns setof _watch.watcher
    language sql
    security definer
    stable
    set search_path = "$user",public
as $$
    select t
    from watch.cached_match_f(payload) w -- updated by watch.reset_cached_fs
    join _watch.watcher t
        on t.id = w.id
    where w.matched = matched_
$$;

\endif