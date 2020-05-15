# syntax=docker/dockerfile:experimental

FROM alpine:3.11

RUN --mount=type=cache,id=apk,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
	apk add --update \
        curl jq bash

COPY docker-artifact.sh /docker-artifact.sh

# Download file from image

RUN /docker-artifact.sh artifact get tom.jpg tomwillfixit/healthcheck:latest

ENTRYPOINT ["/bin/bash"]
