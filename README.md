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

Set your git repository to use Linux end of line configuration. This is important because some scripts written in Windows will not run correctly on your Linux containers later. It's a huge hassle to identify this issue when it comes up. 

- Create a file `.gitignore` in the root of the solution directory
- Enter the following end or line instructions for Git

```bash
*.sh text eol=lf
*.cshtml text eol=lf
```

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


# Write some docker and environment files
We need a few docker files to get the project up and running, and a `.env` file. With the exception of `.dockerignore`, these all go in the solution level folder, not inside of the Umbraco project.

- .`env` Contains your environment variables. At runtime, these override any settings in your dotnet appsettings.json files
- `docker-compose.yml` a configuration file for Docker's compose feature. This makes it easier to manage projects that contain multiple containers
- `docker-entrypoint.sh` a shell script to execute when the docker container starts up. We'll use this to install our database
- `docker-setup.sql` a sql script to be executed by `docker-entrypoint.sh`
- `dockerfile.mssql` an instruction set for Docker to build the mssql server
- `dockerfile.umbracosite` an instruction set for Docker to build the Umbraco applications
- `./UmbracoDockerProject/.dockerignore` a list of files you'd like to exclude from docker's build processes. *Note that this file goes into your Umbraco project, not at the solution level*


## `dockerfile.umbracosite`

For simple projects, a dockerfile will just be named `dockerfile`. In this project, as we have multiple different docker images, they've each got an identifier as a suffix.

### What's happening here?

The file below:

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

Once you've created this script, you should be able to run `docker build ./ -t umbraco-in-docker -f dockerfile.umbracosite` to build the image. The first time you run this script, it'll take a long time, as it needs to pull down a lot of dependencies. 

Once it's complete, you should be able to open Docker Desktop, click on *Images*, and see an image named `umbraco-in-docker`:

![Alt text](readmefiles/image-2.png)


## `docker-compose.yml`

Now that we have an image, we can automate its composition with Docker Compose