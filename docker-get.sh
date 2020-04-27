#!/usr/bin/env bash

docker_get_plugin_metadata() {
	local vendor="tomwillfixit"
	local version="v0.0.1"
	local url="https://medium.com/@thomas.shaw78/extracting-a-single-artifact-from-a-docker-image-without-pulling-3fc038a6e57e"
	local description="Get a file from Image in Docker Hub without pulling the image"
	cat <<-EOF
	{"SchemaVersion":"0.1.0","Vendor":"${vendor}","Version":"${version}","ShortDescription":"${description}","URL":"${url}"}
EOF
}

docker_get() {
	echo "run get commands in here"
}

case "$1" in
	docker-get-plugin-metadata)
		docker_get_plugin_metadata
		;;
	*)
		docker_get
		;;
esac
