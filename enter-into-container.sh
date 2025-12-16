#!/bin/bash

dockerfile="$1"

if [[ ! -f ${dockerfile} ]]; then
    echo "Error: Arg1 must be an existing dockerfile"
    exit 1
fi

name=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f2)
tag=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f3)
image_name=hopsan-build-${name}${tag}

set -e

sudo docker build --file ${dockerfile} --tag ${image_name}:latest .
sudo docker images
sleep 2

host_deps_cache=$(pwd -P)/hopsan-dependencies-cache
host_code_dir=$(pwd -P)/${image_name}-code
host_build_dir=$(pwd -P)/${image_name}-build
host_install_dir=$(pwd -P)/${image_name}-install
host_package_output_dir=$(pwd -P)/hopsan-packages

mkdir -p "${host_deps_cache}"
mkdir -p "${host_code_dir}"
mkdir -p "${host_build_dir}"
mkdir -p "${host_install_dir}"
mkdir -p "${host_package_output_dir}"

# Launch bash in an ephemeral container
sudo docker run --user $(id -u):$(id -g) \
                --mount type=bind,src=${host_deps_cache},dst=/hopsan/deps \
                --mount type=bind,src=${host_code_dir},dst=/hopsan/code \
                --mount type=bind,src=${host_build_dir},dst=/hopsan/build \
                --mount type=bind,src=${host_install_dir},dst=/hopsan/install \
                --tty  --interactive --name ${image_name}-runner --entrypoint /bin/bash --rm ${image_name}
