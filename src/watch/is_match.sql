\if :{?watch_is_natch_sql}
\else
\set watch_is_match_sql true

-- likely for debugging purpose
--
create function watch.is_match(
    w _watch.watcher,
    p anyelement
)
    returns boolean
    language plpgsql
    stable
    set search_path = "$user",public
as $$
declare
    a boolean;
begin
    if w.payload_t <> pg_typeof(p)::text
    then
        return false;
    end if;


    execute format ('select %s (%s%s)',
        w.match_f::regprocedure::regproc,
        (select case
            when w.context_t is null then ''
            else format('jsonb_populate_record(null::%s, %L::jsonb), ',
                w.context_t,
                w.context
            )
            end
        ),
        '$1')
    into a
    using p;
    return a;
end;
$$;


create function watch.get_watcher_by_id (
    id_ text
)
    returns _watch.watcher
    language sql
    stable
as $$
    select w
    from _watch.watcher w
    where w.id = id_
$$;


\endif