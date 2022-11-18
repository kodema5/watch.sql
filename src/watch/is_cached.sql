\if :{?watch_is_cached_sql}
\else
\set watch_is_cached_sql true


-- checks if function cached
--


-- finds the arguments of a function
--
create function watch.function_arguments (
    fn regprocedure
)
    returns text
    language sql
    stable
as $$
    select string_agg(args, ', ')
    from (
        select format_type(unnest(proargtypes), null) args
        from pg_proc
        where oid = fn
    ) x
$$;

-- a function is cached if it has
-- watch.cached_match_f(payload_t_)
--
-- see: reset_cached_fs for detail
--
create function watch.is_cached (
    payload_t_ regtype
)
    returns boolean
    language sql
    stable
as $$
    select (
        rebuilt_tz is not null
        and watcher_tz is not null
        and rebuilt_tz >= watcher_tz
        and exists (
            select 1
            from pg_proc p
            join pg_namespace n
                on p.pronamespace = n.oid
            where n.nspname = 'watch'
                and proname = 'cached_match_f'
                and watch.function_arguments(p.oid) = payload_t_::text
        )
    )
    from _watch.payload
    where id = payload_t_
$$;

-- updates watcher_tz last-updated
--
create function watch.set_payload_watcher_tz_trigger()
    returns trigger
    language plpgsql
    security definer
as $$
begin
    update _watch.payload
    set watcher_tz = clock_timestamp()
    where id = new.payload_t;

    return coalesce(new, old);
end;
$$;

do $$
begin
    if not exists (
        select 1
        from pg_trigger
        where tgrelid = '_watch.watcher'::regclass
            and tgname = 'watch_set_payload_watcher_tz_trigger'
    ) then
        create trigger watch_set_payload_watcher_tz_trigger
        after insert or update
        on _watch.watcher
        for each row
        execute procedure watch.set_payload_watcher_tz_trigger();
    end if;

end;
$$;

\endif