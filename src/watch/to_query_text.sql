-- builds the query-text

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