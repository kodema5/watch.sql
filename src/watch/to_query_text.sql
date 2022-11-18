\if :{?watch_to_query_text_sql}
\else
\set watch_to_query_text_sql true

-- builds the query-texts
-- for watchers of given payload type payload_t_
-- returns:
-- select {watcher_id}, match_f([watcher.context, ] payload)
-- union
-- select {watcher_id}, match_f([watcher.context, ] payload)
-- ....

create function watch.to_query_text (
    w _watch.watcher,
    payload_literal text default '$1'
)
    returns text
    language sql
    stable
as $$
    -- returns id, match_f([context], $1)
    select format ('select %L, %s (%s%s)',
        w.id,
        w.match_f::regproc,
        (select case
            when w.context_t is null then ''
            else format('jsonb_populate_record(null::%s, %L::jsonb), ',
                w.context_t,
                w.context
            )
            end
        ),
        payload_literal
    );
$$;


create function watch.to_query_texts (
    payload_t_ regtype,
    payload_literal text default '$1'
)
    returns text
    language sql
    stable
as $$
    select
        array_to_string(array_agg(
            watch.to_query_text(w, payload_literal)
        ), ' union ')
    from _watch.watcher w
    where w.payload_t = payload_t_
$$;

\endif