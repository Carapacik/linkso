SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'test_database',
    :'database_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'test_database'
)
\gexec
