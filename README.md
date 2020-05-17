# Docker Artifact CLI plugin (renamed from docker get)

This CLI plugin simplifies adding labels to file artifacts within a Docker Image and enables getting files from an Image in Amazon Elastic Container Registry and  Docker Hub without pulling the image. This is a #justforfun #sparetime project and can be used as is. If folks find this useful please star and maybe mention on Twitter (@tomwillfixit). Thanks.

# Prerequisites

The Docker Artifact plugin requires curl, jq and awscli if you are pulling artifacts from Amazon Elastic Container Registry.

# Why?

In Multi Stage builds it is common practice to copy artifacts from other container images at build time using this type of command :
```
COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp
```
This command results in the whole tomwillfixit/test:latest image being pulled.

Using "docker artifact" we can just pull the files we need with a command like this :
```
RUN ./docker-artifact get tom.jpg happy.jpg tomwillfixit/healthcheck:latest
```
This command relies on a LABEL pointing to the layer containing the "happy.jpg" file and we pull just that single layer.

Based on this [post](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

# Prerequisites

You must be using Docker 19.03 or newer for the plugin to work.

1. create the plugins directory

    ```bash
    mkdir -p ~/.docker/cli-plugins
    ```
2. download the "plugin", and save it as `~/.docker/cli-plugins/docker-artifact` (note: no `.sh` extension!)

    ```bash
    curl https://raw.githubusercontent.com/tomwillfixit/docker-get/master/docker-artifact.sh > ~/.docker/cli-plugins/docker-artifact
    ```
3. make it executable

    ```bash
    chmod +x ~/.docker/cli-plugins/docker-artifact
    ```

4. run the `help` command to verify the plugin was installed

    ```bash
    docker help
    ...
    Management Commands:
  	app*        Docker Application (Docker Inc., v0.8.0)
  	artifact*   Manage Artifacts in Docker Images (tomwillfixit, v0.0.1)
    ```
    
5. Try it out!

    Use the "COPY" directive in your Dockerfile to add a file to a single layer of the image.
    Example :
    ```
    COPY important.bin /tmp/important.bin
    ```
    Build the image as normal and push to Docker Hub. 
    
    Now we add the label by running :
    ```
    # docker artifact label important.bin <name of docker image>
    ```
    At this point we can list the files available to get and also get the file directly from Docker Hub without needing to pull the image :
    ```
    # docker artifact ls <name of docker image>
    # docker artifact get important.bin <name of docker image>
    
    ```    
    
    For more details check out [this blog](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

## Usage

```bash
Usage : docker artifact [command]

Command :

 	ls    - List all files available to get 
	get   - Get a file (or multiple files) from an Image 
	label - Add a LABEL to file (or multiple files) inside an Image 

Examples : 

	docker artifact ls tomwillfixit/healthcheck:latest 
	docker artifact get helloworld.bin tom.jpg tomwillfixit/healthcheck:latest 
	docker artifact label helloworld.bin tom.jpg tomwillfixit/healthcheck:latest

```

## Example Output 

List all files available to "get" :

```bash
# docker artifact ls tomwillfixit/healthcheck:latest

[*] Listing Files available to get from Image : tomwillfixit/healthcheck:latest
[*] Retrieve Docker Hub Token
[*] Files available to get :

	- donald.gif
```

Get a single file from an Image in Docker Hub :

```bash
# docker artifact get donald.gif tomwillfixit/healthcheck:latest 

[*] Get File : donald.gif from Docker Image : tomwillfixit/healthcheck:latest
[*] Retrieve Docker Hub Token
[*] Downloading file donald.gif (sha256:c9f499234b79c5eec68b23c0ecb92bed8bc87a734428899abce0d4bb2510e059) ...

```

Add a LABEL to a file in Docker Image :

In order to "get" an individual file from a Docker Image it must first have a specific label.  The Dockerfile should include a line similar to : "COPY donald.gif /tmp/donald.gif". When the image is built, push it to Docker Hub and then run the next command to add a label to the image :

```
# docker artifact label donald.gif tomwillfixit/healthcheck:latest

[*] File Name : donald.gif
[*] Layer ID  : 8b2b71fb3f1c
[*] SHA256    : sha256:c9f499234b79c5eec68b23c0ecb92bed8bc87a734428899abce0d4bb2510e059

[*] Adding LABEL/s to image : tomwillfixit/healthcheck:latest
 --label donald.gif=sha256:c9f499234b79c5eec68b23c0ecb92bed8bc87a734428899abce0d4bb2510e059 
 

This command will search for the Layer ID of the layer containing the file "donald.gif". Using this ID we can find the sha256 value of the blob containing "donald.gif" and a label is added to the image and pushed to Docker Hub. At this point we can use the docker artifact get command to pull the single file.

If you get a message similar to "No label found for file : donald.gif" then it means the image hasn't been pushed to Docker Hub.

```

## Example Dockerfile 

```
# syntax=docker/dockerfile:experimental

FROM alpine:3.11

RUN --mount=type=cache,id=apk,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
	apk add --update \
        python3 curl jq bash

# Upgrade pip3  
RUN --mount=type=cache,id=pip,target=/root/.cache/pip pip3 install -U pip

# Install awscli 
RUN --mount=type=cache,id=pip,target=/root/.cache/pip pip3 install awscli==1.18.9 fastly 

COPY docker-artifact.sh /docker-artifact.sh

# Download file from image

RUN /docker-artifact.sh artifact get tom.jpg tomwillfixit/healthcheck:latest

ENTRYPOINT ["/bin/bash"]
```
Build Image :
```
DOCKER_BUILDKIT=1 docker build -t artifact:latest .
```

When this image is built using BuildKit, 2 mount caches are created; one called apk and one called pip.  These can be found with :
```
docker system df -v |grep cachemount
CACHE ID            CACHE TYPE          SIZE                CREATED             LAST USED           USAGE               SHARED
0pgv0dm2h4c6        exec.cachemount     22.3MB              37 minutes ago      About a minute ago   2                   false
wmar9c2c0nb5        exec.cachemount     21.1MB              36 minutes ago      About a minute ago   5                   false

The cache is stored under /var/lib/docker/overlay2/<cache id>

The number of times the cache is used is a useful value and can help determine which caches are the most useful.

```
## Comparison

Comparing a regular docker build with RUN --copy against a build using [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) and docker-artifact.

```
time docker build --no-cache -t artifact:latest -f Dockerfile.old .

Sending build context to Docker daemon  1.224MB
Step 1/4 : FROM alpine:3.11
 ---> f70734b6a266
Step 2/4 : RUN apk add --update     curl jq bash
 ---> Running in 1b1a060187ca
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/community/x86_64/APKINDEX.tar.gz
(1/10) Installing ncurses-terminfo-base (6.1_p20200118-r4)
(2/10) Installing ncurses-libs (6.1_p20200118-r4)
(3/10) Installing readline (8.0.1-r0)
(4/10) Installing bash (5.0.11-r1)
Executing bash-5.0.11-r1.post-install
(5/10) Installing ca-certificates (20191127-r1)
(6/10) Installing nghttp2-libs (1.40.0-r0)
(7/10) Installing libcurl (7.67.0-r0)
(8/10) Installing curl (7.67.0-r0)
(9/10) Installing oniguruma (6.9.4-r0)
(10/10) Installing jq (1.6-r0)
Executing busybox-1.31.1-r9.trigger
Executing ca-certificates-20191127-r1.trigger
OK: 10 MiB in 24 packages
Removing intermediate container 1b1a060187ca
 ---> 60a5294cb42c
Step 3/4 : COPY --from=tomwillfixit/healthcheck:latest /tmp/tom.jpg .
latest: Pulling from tomwillfixit/healthcheck
207e252fc310: Pull complete 
32689c3f8745: Pull complete 
2db578c3bba0: Pull complete 
799f3a35dfec: Pull complete 
f18fc9811693: Pull complete 
e843085f4be7: Pull complete 
Digest: sha256:72d3a7d24e06f3c32e31d84f03a527fd4a492c34262f4c882251f2c4c10edc3f
Status: Downloaded newer image for tomwillfixit/healthcheck:latest
 ---> 5790f2288697
Step 4/4 : ENTRYPOINT ["/bin/bash"]
 ---> Running in f88d2f49c95f
Removing intermediate container f88d2f49c95f
 ---> 20face702798
Successfully built 20face702798
Successfully tagged artifact:latest

real	0m10.953s
user	0m0.175s
sys	0m0.157s

Docker BuildKit : 

time DOCKER_BUILDKIT=1 docker build --no-cache -t artifact:latest .
[+] Building 7.5s (11/11) FINISHED                                                                                                                                                                              
 => [internal] load build definition from Dockerfile                                                                                                                                                       0.0s
 => => transferring dockerfile: 37B                                                                                                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                                                                          0.0s
 => => transferring context: 2B                                                                                                                                                                            0.0s
 => resolve image config for docker.io/docker/dockerfile:experimental                                                                                                                                      1.5s
 => CACHED docker-image://docker.io/docker/dockerfile:experimental@sha256:de85b2f3a3e8a2f7fe48e8e84a65f6fdd5cd5183afa6412fff9caa6871649c44                                                                 0.0s
 => [internal] load metadata for docker.io/library/alpine:3.11                                                                                                                                             0.0s
 => [internal] load build context                                                                                                                                                                          0.0s
 => => transferring context: 40B                                                                                                                                                                           0.0s
 => CACHED [stage-0 1/4] FROM docker.io/library/alpine:3.11                                                                                                                                                0.0s
 => [stage-0 2/4] RUN --mount=type=cache,id=apk,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache &&  apk add --update         curl jq bash                                                       3.0s
 => [stage-0 3/4] COPY docker-artifact.sh /docker-artifact.sh                                                                                                                                              0.1s
 => [stage-0 4/4] RUN /docker-artifact.sh artifact get tom.jpg tomwillfixit/healthcheck:latest                                                                                                             2.5s 
 => exporting to image                                                                                                                                                                                     0.1s 
 => => exporting layers                                                                                                                                                                                    0.1s 
 => => writing image sha256:1af798e80808e297c4f2c89d4c35f9a6bc2c89d806d601cdfd251c0d7f5b776e                                                                                                               0.0s 
 => => naming to docker.io/library/artifact:latest                                                                                                                                                         0.0s 

real	0m7.611s
user	0m0.097s
sys	0m0.070s


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
