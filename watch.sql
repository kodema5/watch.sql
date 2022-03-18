create extension if not exists "uuid-ossp" schema public;
create extension if not exists pgcrypto schema public;
create extension if not exists ltree schema public;

------------------------------------------------------------------------------
-- data
\if :local
    drop schema if exists watch_ cascade;
\endif
create schema if not exists watch_;
\ir src/watch_/index.sql

------------------------------------------------------------------------------
-- code
drop schema if exists watch cascade;
create schema watch;
\ir src/watch/index.sql


\if :test
    -- a payload
    create type tests.payload_t as (
        a int,
        b int
    );

    insert into watch_.payload (id)
        values (
            'tests.payload_t'::regtype
        );


    -- first matcher accepts a tests.payload_t
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

    -- second matcher accepts a context_t and tests.payload_t
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
    insert into watch_.watcher (id, payload_t, context_t, context, match_f)
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
        return next ok(not watch.is_cached('tests.payload_t'::regtype), 'function is yet cached ');

        p.a = 1;
        select count(1)
        into n
        from watch.get(p);
        return next ok(n = 1, 'but still can use eval_watcher');

        call watch.reset_cached_fs();
        return next ok(watch.is_cached('tests.payload_t'::regtype), 'functions is cached');


        p.a = 1;
        select count(1)
        into n
        from watch.get_watcher(p);
        return next ok(n = 1, 'able to find watcher');

        p.a = 2;
        p.b = 2;
        select count(1)
        into n
        from watch.get_watcher(p);
        return next ok(n = 1, 'able to find watcher');

        select count(1)
        into n
        from watch.eval_watcher(p);
        return next ok(n = 1, 'able to eval watcher');

        return next ok (
            not watch.is_match(
                watch.get_watcher_by_id('watcher-1'),
                p
            ), 'able to test a watcher-1');

        return next ok (
            watch.is_match(
                watch.get_watcher_by_id('watcher-2'),
                p
            ), 'able to test a watcher-2');

        p.a = 3;
        select count(1)
        into n
        from watch.get_watcher(p);
        return next ok(n = 0, 'able to find no-watcher');


    end;
    $$;

\endif




