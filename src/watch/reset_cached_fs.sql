-- reset all get-match functions
--
create procedure watch.reset_cached_fs()
    language plpgsql
    security definer
as $$
declare
    r record;
begin
    -- remove all cached_match_f
    for r in (
        select p.oid::regprocedure fn
        from pg_proc p
        join pg_namespace n
            on p.pronamespace = n.oid
        where n.nspname = 'watch'
            and p.proname like 'cached_match_f%'
    ) loop
        execute format('drop function if exists %s', r.fn);
    end loop;

    -- rebuild all cached_match_f for each type
    for r in
        select *
        from _watch.payload
    loop
        call watch.build_cached_match_f(r.id);
    end loop;
end;
$$;

-- wraps watchers for a given payload-type into a function
--
create procedure watch.build_cached_match_f (
    payload_t_ regtype
)
    language plpgsql
    security definer
as $$
begin
    update _watch.payload
    set rebuilt_tz = clock_timestamp()
    where id = payload_t_;

    if not exists (
        select 1
        from _watch.watcher
        where payload_t = payload_t_
    )
    then
        call watch.clear_cached_match_f(payload_t_);
        return;
    end if;


    execute format('
        create or replace function watch.cached_match_f (
            p %s
        )
            returns table (id text, matched boolean)
            language sql
            stable
        as $fn$ %s $fn$;
    ',
        payload_t_,
        watch.to_query_texts(payload_t_)
    );
end;
$$;


-- clear cached_match_f
--
create procedure watch.clear_cached_match_f (
    payload_t_ regtype
)
    language plpgsql
    security definer
as $$
begin
    execute format('
    drop function if exists watch.cached_match_f (
        p %s
    )', payload_t_);
end;
$$;


