\if :{?watch_tests_price_tick_sql}
\else
\set watch_tests_price_tick_sql true

\if :test
-- supposed a price tick
create type tests.price_tick_t as (
    ticker text,
    price float
);

-- user is to crate a price watch
--
create type tests.price_watch_t as (
    ticker text,
    price_min float,
    price_max float
);

-- a function to match the tick with price watch
--
create function tests.match(
    p tests.price_watch_t,
    t tests.price_tick_t
)
    returns boolean
    language sql
    immutable
as $$
    select
    p.ticker = t.ticker
    and (p.price_min is null or t.price >= p.price_min)
    and (p.price_max is null or t.price <= p.price_max)
$$;


-- encapsulates registration of a price-watcher
--
create function tests.new_price_watcher (
    a tests.price_watch_t,
    id text default md5(gen_random_uuid()::text)
)
    returns _watch.watcher
    language sql
as $$
    insert into _watch.watcher (id, payload_t, context_t, context, match_f)
    values (
        id,
        'tests.price_tick_t'::regtype,
        'tests.price_watch_t'::regtype,
        to_jsonb(a),
        'tests.match(tests.price_watch_t,tests.price_tick_t)'::regprocedure
    )
    returning *
$$;

-- some tests
--
create function tests.test_watch_price_tick()
    returns setof text
    language plpgsql
as $$
begin

    insert into _watch.payload (id)
    values (
        'tests.price_tick_t'::regtype
    );

    perform tests.new_price_watcher (
        ('MSFT', 200, null)::tests.price_watch_t,
        'msft-above-200'
    );
    perform tests.new_price_watcher (
        ('MSFT', null, 200)::tests.price_watch_t,
        'msft-below-200'
    );
    perform tests.new_price_watcher (
        ('MSFT', 200, 250)::tests.price_watch_t,
        'msft-around-225'
    );

    declare
        p tests.price_tick_t;
    begin
        p.ticker = 'MSFT';

        p.price = 210;
        return next ok(exists (
            select from watch.get(p) a
            where a.id='msft-above-200')
        , 'get msft-above-200');


        p.price = 100;
        return next ok(exists (
            select from watch.get(p) a
            where a.id='msft-below-200')
        , 'get msft-below-200');


        p.price = 227;

        return next ok(exists (
            select from watch.get(p) a
            where a.id='msft-around-225')
        , 'get msft-around-225');

    end;
end;
$$;

\endif
\endif