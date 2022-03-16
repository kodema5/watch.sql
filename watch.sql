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


    create function tests.test_watch()
        returns setof text
        language plpgsql
    as $$
    declare
        n int;
    begin
        -- register watchers
        --
        insert into watch_.watcher (payload_t, context_t, context, match_f)
        values
            (
                'tests.payload_t'::regtype,
                null,
                null,
                'tests.match(tests.payload_t)'::regprocedure
            ),
            (
                'tests.payload_t'::regtype,
                'tests.context_t'::regtype,
                jsonb_build_object('a', 2, 'b', 2),
                'tests.match_w_context(tests.context_t,tests.payload_t)'::regprocedure
            );

        -- rebuild get_match functions
        --
        call watch.reset_match_fs();

        select count(1)
        into n
        from watch.get_watcher(jsonb_populate_record(
            null::tests.payload_t,
            jsonb_build_object(
                'a', 1
            )
        ));
        return next ok(n = 1, 'able to find watcher');

        select count(1)
        into n
        from watch.get_watcher(jsonb_populate_record(
            null::tests.payload_t,
            jsonb_build_object(
                'a', 2,
                'b', 2
            )
        ));
        return next ok(n = 1, 'able to find watcher');
    end;
    $$;

\endif




