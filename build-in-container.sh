#!/bin/bash

set -x

hopsan_git_url=https://github.com/Hopsan/hopsan.git

dockerfile="$1"
git_ref="$2"

if [[ ! -f ${dockerfile} ]]; then
    echo "error"
    exit 1
fi

if [[ -z "$git_ref" ]]; then
    echo "error 2"
    exit 1
fi

name=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f2)
tag=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f3)

image_name=hopsan-build-${name}${tag}

sudo docker build --file ${dockerfile} --tag ${image_name}:latest .
sudo docker images

host_deps_cache=$(pwd -P)/dependencies-cache
host_code_dir=$(pwd -P)/${image_name}-code
host_build_dir=$(pwd -P)/${image_name}-build
host_install_dir=$(pwd -P)/${image_name}-install

mkdir -p ${host_deps_cache}
mkdir -p ${host_code_dir}
mkdir -p ${host_build_dir}
mkdir -p ${host_install_dir}

echo
echo ==============================
echo Downloading source code
echo ==============================
echo
pushd ${host_code_dir}
if [[ ! -d ".git" ]]; then
    git clone ${hopsan_git_url} .
    git submodule update --init
fi
git fetch --all --prune
git reset --hard ${git_ref}
#git clean -ffdx
pushd dependencies
#./download-dependencies.py --cache ${host_deps_cache} all (need commit from other branch)
./download-dependencies.py --all
popd
popd

echo
echo ==============================
echo Building inside container
echo ==============================
echo

sudo docker run --user $(id -u):$(id -g) \
     --mount type=bind,src=${host_deps_cache},dst=/hopsan/deps \
     --mount type=bind,src=${host_code_dir},dst=/hopsan/code \
     --mount type=bind,src=${host_build_dir},dst=/hopsan/build \
     --mount type=bind,src=${host_install_dir},dst=/hopsan/install \
     --tty --name ${image_name}-builder --rm ${image_name} bash -c \
     "set -e; \
      pushd /hopsan/code/dependencies; \
      ./setupAll.sh; \
      popd; \
      pushd /hopsan/build; \
      source /hopsan/code/dependencies/setHopsanBuildPaths.sh; \
      echo HOPSAN_BUILD_QT_QMAKE \${HOPSAN_BUILD_QT_QMAKE}; \
      \${HOPSAN_BUILD_QT_QMAKE} /hopsan/code/HopsanNG.pro -r -spec linux-g++ -config release; \
      make -j8; \
      popd; \
      pushd /hopsan/code; \
      set +e; \
      packaging/copyInstallHopsan.sh ./ /hopsan/install; \
      popd"
