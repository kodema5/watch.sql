\if :{?watch_sql}
\else
\set watch_sql true

create extension if not exists "uuid-ossp" schema public;
create extension if not exists pgcrypto schema public;
create extension if not exists ltree schema public;

------------------------------------------------------------------------------
-- data
\if :local
    drop schema if exists _watch cascade;
\endif
create schema if not exists _watch;
\ir src/_watch/index.sql

------------------------------------------------------------------------------
-- code
drop schema if exists watch cascade;
create schema watch;
\ir src/watch/index.sql


\ir tests/index.sql

\endif