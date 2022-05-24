create function watch.get_watcher (
    payload anyelement,
    matched_ boolean default true
)
    returns setof _watch.watcher
    language sql
    security definer
    stable
as $$
    select t
    from watch.cached_match_f(payload) w -- updated by watch.reset_cached_fs
    join _watch.watcher t
        on t.id = w.id
    where w.matched = matched_
$$;
