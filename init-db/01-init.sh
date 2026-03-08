#!/bin/bash
set -e

# Создаёт базы данных для каждого проекта.
# Выполняется один раз при первом запуске postgres.
# Для добавления нового проекта — добавить строку CREATE DATABASE.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
    CREATE DATABASE groceries_db;
    CREATE DATABASE gw2tp_db;
SQL
