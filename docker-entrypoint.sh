#!/bin/bash
set -e

if [ "$1" = '/opt/mssql/bin/sqlservr' ]; then
  # If this is the container's first run, initialize the application database
  if [ ! -f /tmp/app-initialized ]; then
    # Initialize the application database asynchronously in a background process. This allows a) the SQL Server process to be the main process in the container, which allows graceful shutdown and other goodies, and b) us to only start the SQL Server process once, as opposed to starting, stopping, then starting it again.
    function initialize_app_database() {
      # Wait a bit for SQL Server to start. SQL Server's process doesn't provide a clever way to check if it's up or not, and it needs to be up before we can import the application database
      sleep 15s

      #run the setup script to create the DB and the schema in the DB
      # These variables are passed in from docker-compose.yml, via dockerfile.mssql
      # Don't print them except for debugging
      # echo "Hello v1: $1" # -- this should be '/opt/mssql/bin/sqlservr'
      # echo "Hello v2: $2" # -- this should be your server name
      # echo "Hello v3: $3" # -- this should be your server admin username (usually sa)
      # echo "Hello v4: $4" # -- this should be your server admin password 
      # echo "Hello v5: $5" # -- this should be your umbraco database name 
      # echo "Hello v6: $6" # -- this should be your umbraco databasse username 
      # echo "Hello v7: $7" # -- this should be your umbraco database password 

      # The script does the following:
      #  1. Creates a database with name corresponding to $5
      #  2. Creates a login with name corresponding to $6
      #  3. Creates a username with name corresponding to $6_USER 
      #  4. Grants the user/login with datareader/datawriter/ddladmin roles over the database

      /opt/mssql-tools/bin/sqlcmd -S $2 -U $3 -P $4 -d master -i docker-setup.sql -v UMBRACO_DB_NAME="$5" UMBRACO_DB_USER_LOGIN="$6" UMBRACO_DB_USER_PASSWORD="$7" UMBRACO_DB_USER_NAME="$6_USER"
      # /opt/mssql-tools/bin/sqlcmd -S $2 -U $3 -P $4 -d master -i docker-setup.sql

      # Note that the container has been initialized so future starts won't wipe changes to the data
      touch /tmp/app-initialized
    }
    initialize_app_database $1 $2 $3 $4 $5 $6 $7 &
  fi
fi

exec "$@"