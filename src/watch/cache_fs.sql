\if :{?watch_reset_cached_fs_sql}
\else
\set watch_reset_cached_fs_sql true

\ir to_query_text.sql

-- resets all watch.cached_watch_f(...) functions
--
create procedure watch.cache_fs()
    language plpgsql
    security definer
    set search_path = "$user",public
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
        select id
        from _watch.payload
    loop
        call watch.cache_f(to_regtype(r.id));
    end loop;
end;
$$;

-- wraps watchers for a given payload-type into a function
--
-- creates watch.cache_f(payload_t_)
--
create procedure watch.cache_f (
    payload_t_ regtype
)
    language plpgsql
    security definer
as $$
begin
    update _watch.payload
    set rebuilt_tz = clock_timestamp()
    where id = payload_t_::text;

    if not exists (
        select 1
        from _watch.watcher
        where payload_t = payload_t_::text
    )
    then
        call watch.drop_cache_f(payload_t_);
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
        payload_t_::text,
        watch.to_query_texts(payload_t_)
    );
end;
$$;


create procedure watch.drop_cache_f (
    payload_t_ regtype
)
    language plpgsql
    security definer
as $$
begin
    execute format('
    drop function if exists watch.cached_match_f (
        p %s
    )', payload_t_::text);
end;
$$;


\endif