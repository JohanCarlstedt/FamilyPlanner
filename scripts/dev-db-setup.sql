-- Local development database, for running without Docker.
-- Matches ConnectionStrings:Postgres in backend/src/Family.Api/appsettings.Development.json.
--
--   psql -h localhost -p 5433 -U postgres -f scripts/dev-db-setup.sql
--
-- Safe to re-run. Dev credentials only — never use this role or password anywhere real.

SELECT version();

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'family') THEN
        CREATE ROLE family LOGIN PASSWORD 'devpassword';
    END IF;
END
$$;

-- Owning the database gives the role CREATE on its public schema (PostgreSQL 15+
-- no longer grants that to everyone), which the EF migration needs.
SELECT 'CREATE DATABASE family OWNER family'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'family')
\gexec
