#!/usr/bin/env bash

docker_artifact_plugin_metadata() {
	local vendor="tomwillfixit"
	local version="v0.0.1"
	local url="https://t.co/QgwMQIxt4L?amp=1"
	local description="Manage Artifacts"
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
Usage : docker artifact [command]

Command :

 	ls    - List all files available to get 
	get   - Get a file from an Image 
	label - Add a LABEL to file inside Image 

Examples : 

	docker artifact ls tomwillfixit/healthcheck:latest 
	docker artifact get helloworld.bin tomwillfixit/healthcheck:latest 
	docker artifact label helloworld.bin tomwillfixit/healthcheck:latest

"""
exit 0
}

add_label() {

array=( $@ )
len=${#array[@]}
image=${array[$len-1]}
files=${array[@]:0:$len-1}
overlay_sha_location="/var/lib/docker/image/overlay2/distribution/v2metadata-by-diffid/sha256"

OS_TYPE=$(uname -s)

if [[ "${OS_TYPE}" != "Linux" ]] && [[ "${OS_TYPE}" != "Darwin" ]]; then
    echo "[ERROR] ... Detected unsupported OS type : ${OS_TYPE}. Exiting."
    exit 1
fi

for file_name in $(echo ${files});
do 
  layer_id=$(docker history "${image}" --no-trunc |grep "${file_name}" |grep -v LABEL |awk '{print $1}' |cut -d':' -f2 |cut -c1-12)
  if [ -z "${layer_id}" ];then
      	echo "No label found for file : ${file_name}"
	exit 1
  else
	rootfs=$(docker inspect $layer_id |jq -r '.[].RootFS.Layers[-1]' |cut -d":" -f2)
    	if [ "${OS_TYPE}" = "Darwin" ];then
 		file_blob_sha_mac=$(docker run -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i cat ${overlay_sha_location}/${rootfs})
		file_blob_sha=$(echo ${file_blob_sha_mac} |jq -r '.[].Digest'|uniq)
	else
		file_blob_sha=$(cat $overlay_sha_location/$rootfs |jq -r '.[].Digest'|uniq)
	fi

	if [ -z "${file_blob_sha}" ];then
    		echo "Unable to find SHA for file : $file_name"
    		echo "Ensure you have pushed image : $image to Docker Hub"
    		exit 1
	else
		echo "[*] File Name : $file_name"
		echo "[*] Layer ID  : ${layer_id}"
		echo "[*] SHA256    : ${file_blob_sha}"
		LABEL=" --label $file_name=$file_blob_sha ${LABEL}"
	fi
  fi
done

echo -e "[*] Adding LABEL/s to image : $image\n"
echo "${LABEL}"

docker build -t $image ${LABEL} .
docker push $image

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
		docker_artifact_plugin_metadata
		;;
	*)
		if [ -z $2 ] || [ -z $3 ];then
                    	usage
		elif [ "$2" = "ls" ];then
			list_files $3
		elif [ "$2" = "get" ];then
			docker_get $3 $4
		elif [ "$2" = "label" ];then
			echo "${*:3}"
			add_label ${*:3}
		else
			usage
		fi
		;;
esac
