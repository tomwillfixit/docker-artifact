# Docker Get CLI plugin

Plugin to enable getting individual files from a Image in Docker Hub without pulling the image.

Based on this [post](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

# Prerequisites

You must be using Docker 19.03 or newer for the plugin to work.

1. create the plugins directory

    ```bash
    mkdir -p ~/.docker/cli-plugins
    ```
2. download the "plugin", and save it as `~/.docker/cli-plugins/docker-get` (note: no `.sh` extension!)

    ```bash
    curl https://raw.githubusercontent.com/tomwillfixit/docker-get/master/docker-get.sh > ~/.docker/cli-plugins/docker-get
    ```
3. make it executable

    ```bash
    chmod +x ~/.docker/cli-plugins/docker-get
    ```

4. run the `help` command to verify the plugin was installed

    ```bash
    docker help
    ...
    Management Commands:
      app*        Docker Application (Docker Inc., v0.8.0-beta1)
      builder     Manage builds
      buildx*     Build with BuildKit (Docker Inc., v0.2.0-tp)
      get*        Get a File from a Docker Image in Docker Hub (tomwillfixit, v0.0.2)
    ```
    
5. Try it out!

    For this to work the file must have a label on the Docker Image which points to the file sha256 value. For more details check out [this blog](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

## Usage

```bash

Usage:	docker get [option] <filename> <image name> 

Get File from Image

Option:

 	ls  -  List all files available to get

Examples : 

    docker get ls tomwillfixit/healthcheck:latest
    
    docker get tom.jpg tomwillfixit/healthcheck:latest

```

## Example Output 

```bash

# docker get ls tomwillfixit/healthcheck:latest

[*] Listing Files available to get from Image : tomwillfixit/healthcheck:latest
[*] Retrieve Docker Hub Token

[*] Files available to get :

	- donald.gif
	- happy.jpg
	- tom.jpg


# docker get tom.jpg tomwillfixit/healthcheck:latest

[*] Get File : tom.jpg from Docker Image : tomwillfixit/healthcheck:latest
[*] Retrieve Docker Hub Token
[*] Downloading file tom.jpg (sha256:ce16f10346e2302cf5ecc722501c43e44fa1bbfd0a7829ce79ee218ae3292d3a) ...

```

## More Info

```
docker inspect tomwillfixit/healthcheck:latest |jq -r '.[0].Config.Labels'
{
  "donald.gif": "sha256:5b429606ec8119c51b526b4c87ca697cfde680814a7ec1e2a62e0c61782bdbcb",
  "happy.jpg": "sha256:58034856d4d0cbf1be6a96b42a95a0d2376a677106f7792d282fc47f48ceb637",
  "tom.jpg": "sha256:ce16f10346e2302cf5ecc722501c43e44fa1bbfd0a7829ce79ee218ae3292d3a"
}


```
