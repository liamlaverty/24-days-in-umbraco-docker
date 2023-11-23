# Time in Umbraco Docker 🐋

## What is this repo?
An Umbraco 12 site, configured to launch into Linux Docker containers. The project can be run from Windows, Mac, or Linux machines. 

The project creates three containers, then installs Paul Seal's [Clean Starter Kit](https://our.umbraco.com/packages/starter-kits/clean-starter-kit/) with an unattended install:

- Frontend site
- Backoffice site
- MS-SQL database

## Credentials

Backoffice credentials:

- Username: Administrator
- Email: admin@example.com
- Password: One234567890@

# Starting from scratch

## Prepare your project for Docker & Linux

Set your git repository to use Linux end of line configuration for `.sh` and `.cshtml` files. This is important because some scripts written in Windows will not run correctly on your Linux containers later. It's a huge hassle to identify this issue when it comes up. 

- Create a file `.gitignore` in the root of the solution directory
- Enter the following end or line instructions for Git

```bash
*.sh text eol=lf
*.cshtml text eol=lf
```

To verify and adjust this setting on individual files:

- Open the file in VSCode
- At the bottom right, check for either `CRLF` or `LF`, which indicates the file line endings mode
- If set to `CRLF`, update to `LF`

![Alt text](readmefiles/lf-line-endings.png)


## Install Umbraco with the *Clean* package

In VSCode, install Umbraco using [Paul Seal's guide for Clean](https://github.com/prjseal/Clean-Starter-Kit-for-Umbraco-v9)

```bash
# Ensure the latest umbraco templates are installed
dotnet new -i Umbraco.Templates

# Create the solution and project
dotnet new sln --name "UmbracoDocker"
dotnet new umbraco -n "UmbracoDockerProject" --friendly-name "Administrator" --email "admin@example.com" --password "One234567890@" --development-database-type SQLite
dotnet sln add "UmbracoDockerProject"

# add the Clean starter kit
dotnet add "UmbracoDockerProject" package clean

# Run the project
dotnet run --project "UmbracoDockerProject"
```
You should now have an Umbraco v12 site running in the browser:

![Alt text](./readmefiles/image.png)

## Install Docker Desktop

- Visit https://www.docker.com/products/docker-desktop/
- Download and install the application, you don't need to create a Docker account
- Launch the application

You should now have Docker Desktop, along with all of its dependencies. Open VSCode's terminal and enter 

`docker -v`

and 

`docker-compose -v`

to check both are installed


![Alt text](./readmefiles/image-1.png)


# Create Docker and environment files
We need a few docker files to get the project up and running, and a `.env` file. With the exception of `.dockerignore`, these all go in the solution level folder, not inside of the Umbraco project.

- .`env` Contains your environment variables. At runtime, these override any settings in your dotnet appsettings.json files
- `docker-compose.yml` a configuration file for Docker's compose feature. This makes it easier to manage projects that contain multiple containers
- `docker-entrypoint.sh` a shell script to execute when the docker container starts up. We'll use this to install our database
- `docker-setup.sql` a sql script to be executed by `docker-entrypoint.sh`
- `dockerfile.mssql` an instruction set for Docker to build the mssql server
- `dockerfile.umbracosite` an instruction set for Docker to build the Umbraco applications
- `./UmbracoDockerProject/.dockerignore` a list of files you'd like to exclude from docker's build processes. *Note that this file goes into your Umbraco project, not at the solution level*

# Containerise your Umbraco site

## `UmbracoDockerProject/.dockerignore`

Create a file `.dockerignore` in your Umbraco project directory (the directory with the .csproj file, as opposed to the one with the .sln file)

### The file

```bash
**/bin/
**/obj/
```

### What's the file doing?

This tells Docker to ignore the `bin` and `obj` directories when building your images. This ensures you don't accidentally include locally built assemblies in your docker images.

## `dockerfile.umbracosite`

For simple projects, a dockerfile will just be named `dockerfile`. In this project, as we have multiple different docker images, they've each got an identifier as a suffix.

### The file

```dockerfile
# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:7.0 as build-env 

# Build Stage
WORKDIR /src
COPY ["UmbracoDockerProject/UmbracoDockerProject.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish UmbracoDocker.sln --configuration Release --output /publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/sdk:7.0 as runtime-env
WORKDIR /publish
COPY --from=build-env /publish .
ENV ASPNETCORE_URLS "http://+:80"
EXPOSE 80
ENTRYPOINT [ "dotnet", "UmbracoDockerProject.dll"]
```

### What's the file doing?
- Build stage:
  - Pulls down the base image of dotnet 7.0
  - Copies the `UmbracoDocker/UmbracoDockerProject.csproj"` csproj into the image
  - Installs all of its dependencies
  - Builds the site in Release configuration
  - Publishes the built application to `/publish` 
- Runtime stage:
  - Pulls down the base image of dotnet 7.0
  - Sets the working directory to `/publish`
  - Copies the content from the build stage into the runtime working directory
  - Exposes port 80 to allow internet access
  - Sets the entrypoint for the application to the Umbraco site's DLL

Once you've created this script, you should be able to run `docker build ./ -t umbraco-in-docker -f dockerfile.umbracosite` to build the image. The first time you run this script, it'll take a long time, as it needs to pull down a lot of dependencies. 

Once it's complete, you should be able to open Docker Desktop, click on *Images*, and see an image named `umbraco-in-docker`:

![Alt text](readmefiles/image-2.png)


## `docker-compose.yml`
Now that we've got an image, we can create and launch a container using *Docker Compose*. Create the following `docker-compose.yml` file in the soltion directory.

### The file

```yml
version: '3'

services: 
  umbraco_website:
    build:
      context: .
      dockerfile: dockerfile.umbracosite
    restart: always
    ports:
      - 5011:80
    volumes:
      - umbraco_media:/publish/wwwroot/media
volumes: 
  umbraco_media: 
    external: false
```

### What's the file doing?

- The `services` node defines a named `umbraco_website`
- sets the context (location) of the service to the current directory `.`
- sets the dockerfile for the service to `dockerfile.umbracosite`  
- ensures the service restarts any time is stops or encounters an erorr
- sets the ports for the application to be exposed on. Note that if the port is in use by another application on the host computer, you'll receive an error like `Bind for 0.0.0.0:5011 failed: port is already allocated`
- Configures the directory `/publish/wwwroot/media` inside of the container to use a docker volume named `umbraco_media`
- Sets up a volume for `umbraco_media`

Run the command `docker-compose up`. This will successfully launch an Umbraco site with the message **Boot Failed**... But at least we know the code runs. 

![Alt text](readmefiles/docker-boot-failed.png)

Docker Desktop should now have an entry in its *Containers* section named `time-in-umbraco-docker`, with a website `umbraco_website-1`.

![Alt text](readmefiles/docker-container.png)

You'll also have a volume named `time-in-umbraco-docker_umbraco-media`.

![Alt text](readmefiles/docker-volume.png)


### Why isn't the site running?

We can inspect the log files to find out why the site isn't running. In docker desktop, select *Containers*, then select *Umbraco_Website-1*, click *Files*, then scroll down the list to the application directory `./publish/umbraco/Logs/UmbracoTraceLog.[datetime].json`. Right click the file and select *Edit* to quickly inspect the file. 

Reading through the logs, there's no database configured for the site!

![Alt text](readmefiles/docker-umbraco-logs.png)


# Containerise your MSSQL database
Containerisng the MSSQL server is a bit more involved than the Umbraco applicaiton was, and will require a few files. 


## dockerfile.mssql
Similar to the `dockerfile.umbracosite` file, we need to tell Docker how to create the MSSQL server image

### The file

```dockerfile
FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

RUN mkdir -p /var/opt/sqlserver

RUN chown mssql /var/opt/sqlserver

EXPOSE 1433/tcp

COPY docker-setup.sql /
COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

# entrypoint & cmd are set by the docker compose file
ENTRYPOINT [ ]
CMD [ ]

```

### What's the file doing?

- Specify the base image to use. Currently configured to use 2022-latest, but you may have different requirements or licenses with Micrsoft. Adjust this setting appropriately. 
- Temporarily switch the user to root so that we can create the required SQL Server directories
- Creates the `/var/opt/sqlserver` directory and sets `mssql` as an owner of the directory
- Exposes the server over port `1433`
- Copies two files to the image `docker-setup.sql` and `docker-entrypoint.sh` (these are created in the next steps)
- makes `docker-entrypoint.sh` an executable file
- configures empty entrypoints & command instructions. We'll configure these in `docker-compose.yml` soon


Create empty files named `docker-entrypoint.sh` and `docker-setup.sql`. You should now be able to run `docker build ./ -t umbraco-in-docker-mssql-server -f dockerfile.mssql`, after which, your Docker Desktop's list of images will include `umbraco-in-docker-mssql-server`.


## `docker-entrypoint.sh`

This shell script is executed by Docker whenever the mssql server starts up. It's configured in the `docker-compose.yml` file. It's modified from Carl Sargunar's [Umbraco Docker Workshop scripts](https://github.com/CarlSargunar/Umbraco-Docker-Workshop/blob/main/Workshop%20Complete/UmbData/startup.sh)

Make sure the file `docker-entrypoint.sh` is set to `LF` line endings

### The file
```shell
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

      # The script does the following:
      #  1. Creates a database with name corresponding to argument $5
      #  2. Creates a login with name corresponding to argument $6
      #  3. Creates a username with name corresponding to argument $6_USER 
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

```

### What's the file doing?

- Declares itself as a shell script
- Sets the script to exit if there are any errors
- Checks the first argument passed to it is `'/opt/mssql/bin/sqlservr'` to verify we're running the correct shell script
- Inspects the `/tmp/app-initialized` file to see if this is the container's first run. If so, runs through the setup script
- runs the script `docker-setup.sql` with the arguments passed into the script
- marks the container as initialised, by touching `/tmp/app-initialized`


## `docker-setup.sql`

The `docker-entrypoint.sh` file executes this file the first time a container is run. It accepts some arguments, creates a database, and assigns a SQL user to it. It's modified from Carl Sargunar's [Umbraco Docker Workshop scripts](https://github.com/CarlSargunar/Umbraco-Docker-Workshop/blob/main/Workshop%20Complete/UmbData/setup.sql)


### The file
```sql
IF NOT EXISTS(SELECT * FROM sys.databases WHERE name = '$(UMBRACO_DB_NAME)')
    BEGIN
        CREATE DATABASE [$(UMBRACO_DB_NAME)]
    END

CREATE LOGIN $(UMBRACO_DB_USER_LOGIN)   
    WITH PASSWORD = '$(UMBRACO_DB_USER_PASSWORD)';  
GO  

-- Creates a database user for the login created above.  
USE [$(UMBRACO_DB_NAME)]
    CREATE USER $(UMBRACO_DB_USER_NAME) FOR LOGIN $(UMBRACO_DB_USER_LOGIN);  
GO  

USE [$(UMBRACO_DB_NAME)]
    ALTER ROLE db_datareader ADD MEMBER $(UMBRACO_DB_USER_NAME)
GO  

USE [$(UMBRACO_DB_NAME)]    
    ALTER ROLE db_datawriter ADD MEMBER $(UMBRACO_DB_USER_NAME)
GO  

USE [$(UMBRACO_DB_NAME)]
    ALTER ROLE db_ddladmin ADD MEMBER $(UMBRACO_DB_USER_NAME)
GO
```

### What's the file doing?
Accepts the following arguments from the `docker-compose.yml` file:
- `UMBRACO_DB_NAME` - the name of the Umbraco database
- `UMBRACO_DB_USER_LOGIN` - the DB User's login
- `UMBRACO_DB_USER_PASSWORD` - the DB User's password
- `UMBRACO_DB_USER_NAME` - the DB User's username

- Check if the database `$UMBRACO_DB_NAME` exists, and creates a new one if not
- Creates a login for `$UMBRACO_DB_USER_LOGIN` with the password `$UMBRACO_DB_USER_PASSWORD`
- Creates a database user `$(UMBRACO_DB_USER_NAME)`
- Switches into the Umbraco database, and sets the following user roles to ` $(UMBRACO_DB_USER_NAME)`
  - `db_datareader`
  - `db_datawriter`
  - `db_ddladmin`

These account roles match the current [Database Account Roles](https://docs.umbraco.com/umbraco-cms/fundamentals/setup/requirements#database-account-roles) documentation, but may need adjusting in the future. 


## Adjust the `docker-compose.yml` file

Now that we've got a SQL server image, and all of its startup scripts, we'll need to include it in the `docker-compose.yml` file

---




