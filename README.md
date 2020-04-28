# Docker Get CLI plugin

Plugin to enable getting individual files from a Image in Docker Hub without pulling the image.

Based on this [post](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

# Pre-requisites

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
      get*  Description
    ```
    
5. enjoy!

    ```bash
    docker get
    ```
