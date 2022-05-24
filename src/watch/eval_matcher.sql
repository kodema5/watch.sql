-- if watcher are to be dynamic while execution in other sessions,
-- the cached functions may be invalidated
--
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
