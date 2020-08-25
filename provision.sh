#!/bin/bash


# Provide a file path with scripts to execute.
readonly ARG_FILEPATH=0
BASH_CLI_OPT_NAME[ARG_FILEPATH]="-f"
BASH_CLI_OPT_ALT_NAME[ARG_FILEPATH]="--filepath"
BASH_CLI_OPT_DESC[ARG_FILEPATH]="Path to the SQL scripts to be executed on a database."
BASH_CLI_OPT_DATA_TYPE[ARG_FILEPATH]="string"

## Create user.
readonly ARG_USER=1
BASH_CLI_OPT_NAME[ARG_USER]="-u"
BASH_CLI_OPT_ALT_NAME[ARG_USER]="--user"
BASH_CLI_OPT_DESC[ARG_USER]="User to create for executing the scripts, if not provided, run with admin user."
BASH_CLI_OPT_DATA_TYPE[ARG_USER]="string"

## Create user with password
readonly ARG_PASSWORD=2
BASH_CLI_OPT_NAME[ARG_PASSWORD]="-p"
BASH_CLI_OPT_ALT_NAME[ARG_PASSWORD]="--password"
BASH_CLI_OPT_DESC[ARG_PASSWORD]="Password for the user to create."
BASH_CLI_OPT_DATA_TYPE[ARG_PASSWORD]="string"

## Admin Password
readonly ARG_DBNAME=3
BASH_CLI_OPT_NAME[ARG_DBNAME]="-d"
BASH_CLI_OPT_ALT_NAME[ARG_DBNAME]="--database"
BASH_CLI_OPT_DESC[ARG_DBNAME]="Database to create."
BASH_CLI_OPT_DATA_TYPE[ARG_DBNAME]="string"

## Admin Password
readonly ARG_SHOULD_CREATE=4
BASH_CLI_OPT_NAME[ARG_SHOULD_CREATE]="-c"
BASH_CLI_OPT_ALT_NAME[ARG_SHOULD_CREATE]="--create"
BASH_CLI_OPT_DESC[ARG_SHOULD_CREATE]="Whether to create the database before executing scripts."
BASH_CLI_OPT_DATA_TYPE[ARG_SHOULD_CREATE]="boolean"

## Provision Command
readonly ARG_CMD_PROVISION=5
BASH_CLI_OPT_NAME[ARG_CMD_PROVISION]="provision"
BASH_CLI_OPT_DATA_TYPE[ARG_CMD_PROVISION]="cmd"
BASH_CLI_OPT_ALT_NAME[ARG_CMD_PROVISION]="provision"
BASH_CLI_OPT_DESC[ARG_CMD_PROVISION]="To provision a database with user and execute scripts"
BASH_CLI_MANDATORY_PARAM[ARG_CMD_PROVISION]="${ARG_USER},${ARG_PASSWORD},${ARG_DBNAME}"
BASH_CLI_NON_MANDATORY_PARAM[ARG_CMD_PROVISION]="${ARG_FILEPATH}"


function wait_db() {
  #waiting for postgres
  until psql "$PG_ADMIN_DB" -w &>/dev/null
  do
    psql "$PGDATABASE"
    echo "Waiting for PostgreSQL..."
    sleep 1
  done
}


function create_db() {
  ## Will execute with admin credentials
  local user=${BASH_CLI_OPT_VALUE[ARG_USER]}
  local dbname=${BASH_CLI_OPT_VALUE[ARG_DBNAME]}
  local password=${BASH_CLI_OPT_VALUE[ARG_PASSWORD]}
  echo "Create database $dbname with owner $user."
  psql -v ON_ERROR_STOP=0 <<-EOSQL
  CREATE ROLE "$user" WITH LOGIN PASSWORD '$password';
  CREATE DATABASE "$dbname" OWNER "$user";
  GRANT ALL PRIVILEGES ON DATABASE "$dbname" TO "$user";
EOSQL
}

function execute_sql() {
  ## Will execute with user credentials
  local user=${BASH_CLI_OPT_VALUE[ARG_USER]}
  local dbname=${BASH_CLI_OPT_VALUE[ARG_DBNAME]}
  local password=${BASH_CLI_OPT_VALUE[ARG_PASSWORD]}
  echo "Connect with $user on $dbname for executing $1"
  PGPASSWORD=$password psql -h "$PGHOST" -d "$dbname" -U "$user" -f "$1" 2>&1
}

function provision() {
  wait_db
  if [[ -z "$PGUSER" && -z "$PGDATABASE" ]]; then
  echo "You must specify admin user and admin database to connect to the host."
  echo "Exiting..."
  exit
  fi

  if [[ ${BASH_CLI_OPT_VALUE[ARG_SHOULD_CREATE]} == true ]]; then
    create_db
  else
    echo "Database and user are expected to be existing."
  fi

  local filepath=${BASH_CLI_OPT_VALUE[ARG_FILEPATH]}
  if ! [[ -z "${filepath}" ]]; then
    echo "Running scripts located in $filepath"
    for f in "${filepath}"/*.sql
    do
      [ -e "$f" ] || break
      echo "Executing script at $f"
      execute_sql "$f"
      #PGPASSWORD="$PG_WORKER_PASSWORD" psql -h "$PGHOST" -d "$PGDATABASE" -U "$PGUSER" -f "$f" 2>"$f".err.log
    done
  fi

}
