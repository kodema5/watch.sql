
-- get_watcher returns watcher of a given payload
--
create function watch.get_watcher (
    payload anyelement,
    matched_ boolean default true
)
    returns setof watch_.watcher
    language sql
    security definer
as $$
    select t
    from watch.get_match(payload) w -- replaced by watch.reset_watch_fs
        join watch_.watcher t
            on t.id = w.id
    where w.matched = matched_
$$;


-- for each type, get_match(payload-type) will be created
--
create procedure watch.reset_match_fs ()
    language plpgsql
    security definer
as $$
declare
    r record;
begin
    for r in (
        select p.oid::regprocedure fn
        from pg_proc p
        join pg_namespace n
            on p.pronamespace = n.oid
        where n.nspname = 'watch'
            and p.proname = 'get_match'
    ) loop
        execute format('drop function if exists %s', r.fn);
    end loop;

    call watch.set_match_fs();
end;
$$;


create procedure watch.set_match_fs ()
    language plpgsql
    security definer
as $$
declare
    r record;
begin
    for r in
        select *
        from watch_.payload
    loop
        call watch.set_match_f(r.id);
    end loop;
end;
$$;


-- wraps watchers for a given payload-type into a function
--
create procedure watch.set_match_f (
    payload_t_ regtype
)
    language plpgsql
    security definer
as $$
begin
    if not exists (
        select 1
        from watch_.watcher
        where payload_t = payload_t_
    )
    then
        execute format('
        drop function if exists watch.get_match (
            p %s
        )', payload_t_);
        return;
    end if;


    execute format('
        create or replace function watch.get_match (
            p %s
        )
            returns table (id text, matched boolean)
            language sql
            stable
        as $fn$ %s $fn$;
    ',
        payload_t_,
        (select array_to_string(array_agg(
            format('select %L, %s (%s p)',
                id,
                match_f::regproc,
                (select case
                    when context_t is null then ''
                    else format('jsonb_populate_record(null::%s, %L::jsonb),',
                        context_t,
                        context
                    )
                    end
                )
            )
            ), ' union ')
        from watch_.watcher
        where payload_t = payload_t_)
    );
end;
$$;
