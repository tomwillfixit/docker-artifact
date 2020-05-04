# Docker Artifact CLI plugin (renamed from docker get)

This CLI plugin simplifies adding labels to file artifacts within a Docker Image and enables getting individual files from a Image in Docker Hub without pulling the image. This is a #justforfun #sparetime project and can be used as is. If folks find this useful please star and maybe mention on Twitter (@tomwillfixit). Thanks.

# Why?

In Multi Stage builds it is common practice to copy artifacts from other container images at build time using this type of command :
```
COPY --from=tomwillfixit/test:latest /tmp/shipitcon.jpg /tmp
```
This command results in the whole tomwillfixit/test:latest image being pulled.

Using "docker artifact" we can just pull the files we need with a command like this :
```
RUN ./docker-artifact get shipitcon.jpg tomwillfixit/test:latest
```
This command relies on a LABEL pointing to the layer containing the "shipitcon.jpg" file and we pull just that single layer.

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

    For this to work the file must have a label on the Docker Image which points to the file sha256 value. For more details check out [this blog](https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e).

## Usage

```bash
Usage : docker artifact [command]

Command :

 	ls    - List all files available to get 
	get   - Get a single file from an Image 
	label - Add a LABEL to file or multiple files inside an Image 

Examples : 

	docker artifact ls tomwillfixit/healthcheck:latest 
	docker artifact get helloworld.bin tomwillfixit/healthcheck:latest 
	docker artifact label helloworld.bin tomwillfixit/healthcheck:latest

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
FROM alpine:3.11

RUN apk update && apk add bash jq curl

COPY docker-artifact /docker-artifact

#RUN ./docker-artifact get shipitcon.jpg tomwillfixit/test:latest

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
Step 3/5 : COPY docker-artifact /docker-artifact
 ---> a6b15d7220bd
Step 4/5 : RUN ./docker-artifact get shipitcon.jpg tomwillfixit/test:latest
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
