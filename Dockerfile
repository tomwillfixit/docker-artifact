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
