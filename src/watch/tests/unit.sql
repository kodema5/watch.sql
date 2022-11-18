\if :{?watch_tests_unit_sql}
\else
\set watch_tests_unit_sql true

\if :test
-- a generic payload
create type tests.payload_t as (
    a int,
    b int
);

insert into _watch.payload (id)
    values (
        'tests.payload_t'::regtype
    );


-- a static matcher accepts only tests.payload_t (without context)
-- this can be for system-monitor.
--
create function tests.match (
    p tests.payload_t
)
    returns boolean
    language sql
    stable
as $$
    select (p.a = 1)
$$;

-- another matcher accepts both a context_t and tests.payload_t
-- this can be for a user-supplied parameter
--
create type tests.context_t as (
    a int,
    b int
);

create function tests.match_w_context (
    c tests.context_t,
    p tests.payload_t
)
    returns boolean
    language sql
    stable
as $$
    select (p.a = c.a and p.b = c.b)
$$;


-- register watchers
--
insert into _watch.watcher (id, payload_t, context_t, context, match_f)
values
    (
        'watcher-1',
        'tests.payload_t'::regtype,
        null,
        null,
        'tests.match(tests.payload_t)'::regprocedure
    ),
    (
        'watcher-2',
        'tests.payload_t'::regtype,
        'tests.context_t'::regtype,
        jsonb_build_object('a', 2, 'b', 2),
        'tests.match_w_context(tests.context_t,tests.payload_t)'::regprocedure
    );



create function tests.test_watch()
    returns setof text
    language plpgsql
as $$
declare
    n int;
    p tests.payload_t;
begin
    -- a watcher can be cached or dynamically evaluated
    --
    return next ok(
        not watch.is_cached('tests.payload_t'::regtype),
        'function is yet cached ');

    -- watch.get proxy between cached/dynamic eval routes
    --
    p.a = 1;
    select count(1)
    into n
    from watch.get(p);
    return next ok(
        n = 1,
        'but still can use eval_watcher');

    -- watch.cache_fs rebuilds the cache
    --
    call watch.cache_fs();
    return next ok(
        watch.is_cached('tests.payload_t'::regtype),
        'cache match functions');

    -- check with cached functions
    --
    p.a = 1;
    select count(1)
    into n
    from watch.get_watcher(p);
    return next ok(n = 1, 'find cached watcher');

    p.a = 2;
    p.b = 2;
    select count(1)
    into n
    from watch.get_watcher(p);
    return next ok(n = 1, 'find cached watcher');

    -- check with dynamic evaluation function
    --
    select count(1)
    into n
    from watch.eval_watcher(p);
    return next ok(n = 1, 'dynamic eval for watchers');

    -- watch.is_match accepts a watcher to match with payload
    -- this can be used for debugging purpose
    --
    return next ok (
        not watch.is_match(
            watch.get_watcher_by_id('watcher-1'),
            p
        ), 'test watcher-1');

    return next ok (
        watch.is_match(
            watch.get_watcher_by_id('watcher-2'),
            p
        ), 'test watcher-2');

    -- a test if no match
    --
    p.a = 3;
    select count(1)
    into n
    from watch.get_watcher(p);
    return next ok(n = 0, 'no-watcher found');
end;
$$;

\endif
\endif