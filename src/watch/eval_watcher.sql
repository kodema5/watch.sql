\if :{?watch_eval_watcher_sql}
\else
\set watch_eval_watcher_sql true

-- if watcher are to be dynamic while execution in other sessions,
-- the cached functions may be invalidated

-- eval_watcher dynamically returns the matching watchers
-- select t.*
-- from (
--      select watch_id, match_f({context}, payload))
--      union
--      select watch_id, match_f({context}, payload))
--      ...
-- ) w (id, matched)
-- join _watch.watcher t where t.id = w.id


create function watch.eval_watcher (
    p anyelement,
    matched_ boolean default true
)
    returns setof _watch.watcher
    language plpgsql
    security definer
as $$
declare
    t text;
begin
    return query execute
        format('
            select t.*
            from ( %s ) w (id, matched)
            join _watch.watcher t
                on t.id = w.id
            where w.matched = %L
        ',
        watch.to_query_texts(
            pg_typeof(p),
            '$1'
        ),
        matched_)
    using p;
end;
$$;

\endif