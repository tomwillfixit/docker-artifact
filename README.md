# Docker Get CLI plugin

Docker plugin to enable getting individual files from a Image in Docker Hub without pulling the image. It's quite a common pattern in Multi Stage builds to copy artifacts from other container images at build time using this type of command :
```
COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp
```
This command results in the whole tomwillfixit/test:latest image being pulled.

Using "docker get" we can just pull the files we need with a command like this :
```
RUN ./docker-get get shipitcon.jpg tomwillfixit/test:latest
```
This command relies on a LABEL pointing to the layer containing the "shipitcon.jpg" file and we pull just that single layer.

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

## Label Artifacts

In order to use the "docker get" command you need to have applied labels to each of the files you want to be able to "get".  The label-artifacts script is a work in progress and only works on Linux.

How does it work?

Provide the name of the file and the image it is in and the label-artifact scipt will add a label for the file. This allows us to get the file later.

./label-artifacts <filename> <docker image name>

Example Output :
```
./label-artifacts shipitcon.jpg sic.jpg tomwillfixit/test:latest

File Name : shipitcon.jpg
Layer ID  : b8dd8f676522
SHA256    : sha256:13823b61591ad64cc00fa6530a3370da1458276db7171d0dbeb65c756578ab69

File Name : sic.jpg
Layer ID  : 7f5fd59aa4cd
SHA256    : sha256:16f0fd16f7131a75a18bc48cc65fc75daad408631b141abe7768e75548b10e29

Adding LABEL/s to image : tomwillfixit/test:latest

 --label sic.jpg=sha256:16f0fd16f7131a75a18bc48cc65fc75daad408631b141abe7768e75548b10e29  
 --label shipitcon.jpg=sha256:13823b61591ad64cc00fa6530a3370da1458276db7171d0dbeb65c756578ab69
 
```

## Example Dockerfile 

```
FROM alpine:3.11

RUN apk update && apk add bash jq curl

COPY docker-get /docker-get

#RUN ./docker-get get shipitcon.jpg tomwillfixit/test:latest

COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp

ENTRYPOINT /bin/bash

```

## Example 

When pulling a single file from a 60mb Docker image using "docker get" and no local cache we see roughly a 40% decrease in build time when compared to the same build copying the file with this command : 

COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp

```
time docker build --no-cache -t test:latest .
Sending build context to Docker daemon  691.8MB
Step 1/5 : FROM alpine:3.11
 ---> f70734b6a266
Step 2/5 : RUN apk update && apk add bash jq curl
 ---> Running in 68e8409923ab
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/community/x86_64/APKINDEX.tar.gz
v3.11.6-10-g3d1aef7a83 [http://dl-cdn.alpinelinux.org/alpine/v3.11/main]
v3.11.6-15-g3ae2cc62ea [http://dl-cdn.alpinelinux.org/alpine/v3.11/community]
OK: 11270 distinct packages available
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
Removing intermediate container 68e8409923ab
 ---> a5d0abc39e26
Step 3/5 : COPY docker-get /docker-get
 ---> a6b15d7220bd
Step 4/5 : RUN ./docker-get get shipitcon.jpg tomwillfixit/test:latest
 ---> Running in 317700daaadd
[*] Get File : shipitcon.jpg from Docker Image : tomwillfixit/test:latest
[*] Retrieve Docker Hub Token
[*] File : shipitcon.jpg is not available to get.
Removing intermediate container 317700daaadd
 ---> 1dafa64c740d
Step 5/5 : ENTRYPOINT /bin/bash
 ---> Running in 7f7d07d8f35f
Removing intermediate container 7f7d07d8f35f
 ---> c0b4b41d7f52
Successfully built c0b4b41d7f52
Successfully tagged test:latest

real	0m23.372s
user	0m0.360s
sys	0m0.516s
root@tom-laptop:~/test_plugin# docker rmi tomwillfixit/test:latest
Error: No such image: tomwillfixit/test:latest
root@tom-laptop:~/test_plugin# vi Dockerfile 
root@tom-laptop:~/test_plugin# time docker build --no-cache -t test:latest .
Sending build context to Docker daemon  691.8MB
Step 1/5 : FROM alpine:3.11
 ---> f70734b6a266
Step 2/5 : RUN apk update && apk add bash jq curl
 ---> Running in eb4ee35c32cb
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.11/community/x86_64/APKINDEX.tar.gz
v3.11.6-10-g3d1aef7a83 [http://dl-cdn.alpinelinux.org/alpine/v3.11/main]
v3.11.6-15-g3ae2cc62ea [http://dl-cdn.alpinelinux.org/alpine/v3.11/community]
OK: 11270 distinct packages available
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
Removing intermediate container eb4ee35c32cb
 ---> 9db2b9f1ba55
Step 3/5 : COPY docker-get /docker-get
 ---> c8e6b9f5d297
Step 4/5 : COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp
latest: Pulling from tomwillfixit/test
cbdbe7a5bc2a: Already exists 
bb761cc53ae3: Already exists 
d504619ed165: Already exists 
86a813148ec6: Pull complete 
70526af28813: Pull complete 
Digest: sha256:90631751527bf02b862399163df5b89cd81cfd54a526a1ac527a27f18314fa53
Status: Downloaded newer image for tomwillfixit/test:latest
 ---> f590b482e6bb
Step 5/5 : ENTRYPOINT /bin/bash
 ---> Running in 3923e4be4d47
Removing intermediate container 3923e4be4d47
 ---> bcaa9694a91c
Successfully built bcaa9694a91c
Successfully tagged test:latest

real	1m35.225s
user	0m0.536s
sys	0m0.524s
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
