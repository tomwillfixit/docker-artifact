#!/usr/bin/env bash

# Supports pulling artifacts from Images stored in Amazon Elastic Container Registry and Docker Hub.

docker_artifact_plugin_metadata() {
	local vendor="tomwillfixit"
	local version="v0.0.5"
	local url="https://t.co/QgwMQIxt4L?amp=1"
	local description="Manage Artifacts in Docker Images"
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
	get   - Get a file (or multiple files) from an Image 
	label - Add a LABEL to file (or multiple files) inside an Image 

Examples : 

	docker artifact ls tomwillfixit/healthcheck:latest 
	docker artifact get helloworld.bin happy.jpg tomwillfixit/healthcheck:latest 
	docker artifact label helloworld.bin happy.jpg tomwillfixit/healthcheck:latest

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

array=( $@ )
len=${#array[@]}
docker_image=${array[$len-1]}
files=${array[@]:0:$len-1}

if [[ "${docker_image}" =~ ".ecr." ]];then

	#aws ecr get-download-url-for-layer --repository-name internal-deployment-cli --layer-digest=sha256:c887ee98c22696928d21296a9f2149c572ee22f482c150e72e283a523e5a9684 |jq -r '.downloadUrl'
	region=$(echo $docker_image |cut -d'.' -f4)
        repo=$(echo $docker_image |cut -d':' -f1 |cut -d'/' -f2)
        tag=$(echo $docker_image |cut -d':' -f2)

	for filename in $(echo ${files});
        do
		echo "[*] Get File : $filename from Docker Image : $docker_image"
		file_sha256_value=$(aws ecr batch-get-image \
	        --repository-name ${repo} \
        	--image-id imageTag=${tag} \
        	--region ${region} \
        	--accepted-media-types "application/vnd.docker.distribution.manifest.v1+json" \
        	--output json \
        	|jq -r '.images[].imageManifest' \
        	|jq -r '.history[0].v1Compatibility' \
        	|jq -r --arg FILENAME $filename '.config.Labels |to_entries[] |select(.key==$FILENAME)' |jq -r '.value')
		if [ -z "${file_sha256_value}" ];then
                        echo "[*] File : $filename is not available to get."
                        exit 0
                else
                        echo "[*] Downloading file $filename ($file_sha256_value) ..."
			download_url=$(aws ecr get-download-url-for-layer --repository-name ${repo} --layer-digest=${file_sha256_value} |jq -r '.downloadUrl')
			curl -s -X GET "${download_url}" --output ${filename}.tar
			tar -xvf ${filename}.tar
			rm ${filename}.tar
                fi
	done
else
	reg=registry.hub.docker.com
	repo=$(echo $docker_image |cut -d"/" -f1)
	image=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f1)
	token=$(get_token "$repo/$image")
	tag=$(echo $docker_image |cut -d"/" -f2 |cut -d":" -f2)

	for filename in $(echo ${files});
	do
 		echo "[*] Get File : $filename from Docker Image : $docker_image"	
		file_sha256_value=$(curl --silent -H "Authorization: Bearer $token" https://$reg/v2/$repo/$image/manifests/$tag |jq -r '.history[0].v1Compatibility' |jq -r --arg FILENAME $filename '.container_config.Labels | to_entries[] |select(.key==$FILENAME)' |jq -r '.value')
		if [ -z "${file_sha256_value}" ];then
			echo "[*] File : $filename is not available to get."
			exit 0
		else
        		echo "[*] Downloading file $filename ($file_sha256_value) ..."
 			curl -s -L -H "Authorization: Bearer $token" "https://registry.hub.docker.com/v2/$repo/$image/blobs/$file_sha256_value" |tar -xz
        	fi
	done

fi

}

list_files_ecr_image() {

	ecr_image=$1
	# This piece of code is quite fragile. Assumes ecr naming is standardized.
	region=$(echo $ecr_image |cut -d'.' -f4)
	repo=$(echo $ecr_image |cut -d':' -f1 |cut -d'/' -f2)
	tag=$(echo $ecr_image |cut -d':' -f2)

	files=$(aws ecr batch-get-image \
	--repository-name ${repo} \
	--image-id imageTag=${tag} \
	--region ${region} \
	--accepted-media-types "application/vnd.docker.distribution.manifest.v1+json" \
	--output json \
	|jq -r '.images[].imageManifest' \
	|jq -r '.history[0].v1Compatibility' \
	|jq -r '.config.Labels | to_entries[] | select(.value | contains("sha256"))' |jq -r '.key')

	if [ -z "$files" ];then
                echo "[*] No files found."
        else
                echo -e "\n[*] Files available to get :\n"
                for filename in $(echo ${files})
                do
                        echo "  - ${filename}"
                done
        fi

}

list_files_docker_hub() {

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
                        echo "  - ${filename}"
                done
        fi
}

list_files() {
	docker_image=$1
	echo "[*] Listing Files available to get from Image : ${docker_image}"
        if [[ "${docker_image}" =~ ".ecr." ]];then
            list_files_ecr_image ${docker_image}
	else
	    list_files_docker_hub ${docker_image}
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
			docker_get ${*:3} 
		elif [ "$2" = "label" ];then
			add_label ${*:3}
		else
			usage
		fi
		;;
esac
