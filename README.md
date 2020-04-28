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
      get*        Get a File from a Docker Image in Docker Hub (tomwillfixit, v0.0.1)
    ```
    
5. Try it out!

    For this to work the file must have a label on the Docker Image which points to the file sha256 value. For more details check out [this blog](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

    ```bash
    docker get <name of file> <image in docker hub>
    
    Example : 
    docker get helloworld.bin tomwillfixit/healthcheck:latest
    
    [*] Get File : helloworld.bin from Docker Image : tomwillfixit/healthcheck:latest
    [*] Retrieve Docker Hub Token
    [*] Downloading file helloworld.bin (sha256:2db578c3bba06cf12b67ed42e72b8d0582e62dc2bde2fdcdaf77cb297fbd4fcb) ...
    ```
