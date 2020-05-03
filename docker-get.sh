#!/usr/bin/env bash

docker_get_plugin_metadata() {
	local vendor="tomwillfixit"
	local version="v0.0.2.1"
	local url="https://t.co/QgwMQIxt4L?amp=1"
	local description="Get a File from a Docker Image in Docker Hub"
	cat <<-EOF
	{"SchemaVersion":"0.1.0","Vendor":"${vendor}","Version":"${version}","ShortDescription":"${description}","URL":"${url}"}
EOF
}

get_token() {
  local image=$1
  echo "[*] Retrieve Docker Hub Token" >&2
  curl \
    --silent \
    "https://auth.docker.io/token?scope=repository:$image:pull&service=registry.docker.io" \
    | jq -r '.token'
}

usage() {
	echo """

Usage:	docker get [option] <filename> <image name> 

Get File from Image

Option:

 	ls  -  List all files available to get

Examples : 

	docker get helloworld.bin tomwillfixit/healthcheck:latest

	docker get ls tomwillfixit/healthcheck:latest 

"""
}

docker_get() {
	filename=$1
	docker_image=$2

 	echo "[*] Get File : $filename from Docker Image : $docker_image"	
	reg=registry.hub.docker.com
	repo=$(echo $docker_image |cut -d"/" -f1)
	image=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f1)
 	token=$(get_token "$repo/$image")
	tag=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f2)
	file_sha256_value=$(curl --silent -H "Authorization: Bearer $token" https://$reg/v2/$repo/$image/manifests/$tag |jq -r '.history[0].v1Compatibility' |jq -r --arg FILENAME $filename '.container_config.Labels | to_entries[] |select(.key==$FILENAME)' |jq -r '.value')
	if [ -z "${file_sha256_value}" ];then
		echo "[*] File : $filename is not available to get."
		exit 0
	else
        	echo "[*] Downloading file $filename ($file_sha256_value) ..."
 		curl -s -L -H "Authorization: Bearer $token" "https://registry.hub.docker.com/v2/$repo/$image/blobs/$file_sha256_value" |tar -xz
        fi
}

list_files() {
	docker_image=$1
	echo "[*] Listing Files available to get from Image : ${docker_image}"
	reg=registry.hub.docker.com
	repo=$(echo $docker_image |cut -d"/" -f1)
        image=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f1)
	token=$(get_token "$repo/$image")	
	tag=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f2)
	files=$(curl --silent -H "Authorization: Bearer $token" https://$reg/v2/$repo/$image/manifests/$tag |jq -r '.history[0].v1Compatibility' |jq -r '.container_config.Labels | to_entries[] | select(.value | contains("sha256"))' |jq -r '.key')
	if [ -z "$files" ];then
		echo "[*] No files found."
	else
		echo -e "\n[*] Files available to get :\n"
		for filename in $(echo ${files})
		do
			echo "	- ${filename}"
		done
	fi
	echo ""

}

case "$1" in
	docker-cli-plugin-metadata)
		docker_get_plugin_metadata
		;;
	*)
		if [ -z $2 ] || [ -z $3 ];then
                    	usage
			exit 0
		elif [ "$2" = "ls" ];then
			list_files $3
		else
			docker_get $2 $3
		fi
		;;
esac
