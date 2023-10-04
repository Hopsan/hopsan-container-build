#!/bin/bash

set -x

hopsan_git_url=https://github.com/Hopsan/hopsan.git

dockerfile="$1"
git_ref="$2"
base_version="$3"

do_build=true
do_test=true
do_clean=true

if [[ ! -f ${dockerfile} ]]; then
    echo "Error: Arg1 must be an existing dockerfile"
    exit 1
fi

if [[ -z "$git_ref" ]]; then
    echo "Error: Arg2 must be a git ref (branch, tag or commit hash)"
    exit 1
fi

if [[ -z "$base_version" ]]; then
    echo "Error: Arg3 must be the release version number for Hopsan"
    exit 1
fi

name=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f2)
tag=$(echo ${dockerfile} | cut -d. -f1 | cut -d- -f3)

image_name=hopsan-build-${name}${tag}

sudo docker build --file ${dockerfile} --tag ${image_name}:latest .
sudo docker images

host_deps_cache=$(pwd -P)/hopsan-dependencies-cache
host_code_dir=$(pwd -P)/${image_name}-code
host_build_dir=$(pwd -P)/${image_name}-build
host_install_dir=$(pwd -P)/${image_name}-install
host_package_output_dir=$(pwd -P)/hopsan-packages

mkdir -p ${host_deps_cache}
mkdir -p ${host_code_dir}
mkdir -p ${host_build_dir}
mkdir -p ${host_install_dir}
mkdir -p ${host_package_output_dir}

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
if [[ "${do_clean}" == "true" ]]; then
    git clean -ffdx
fi
pushd dependencies
# Figure out if cache option is available in the version being built
if ./download-dependencies.py --help | grep cache; then
    ./download-dependencies.py --cache "${host_deps_cache}" --all
else
    ./download-dependencies.py --all
fi
popd
release_revision=$(./getGitInfo.sh date.time .)
full_version_name=${base_version}.${release_revision}
echo Release revision number: $release_revision
echo Release version name: $full_version_name
sleep 2
popd

echo
echo ==============================
echo Building inside container
echo ==============================
echo

if [[ "${do_build}" == "true" ]]; then

    if [[ "${do_clean}" == "true" ]]; then
        rm -rf ${host_build_dir}
        rm -rf ${host_install_dir}
    fi
    mkdir -p ${host_build_dir}
    mkdir -p ${host_install_dir}

    sudo docker run --user $(id -u):$(id -g) \
         --mount type=bind,src=${host_deps_cache},dst=/hopsan/deps \
         --mount type=bind,src=${host_code_dir},dst=/hopsan/code \
         --mount type=bind,src=${host_build_dir},dst=/hopsan/build \
         --mount type=bind,src=${host_install_dir},dst=/hopsan/install \
         --tty --name ${image_name}-builder --rm ${image_name} bash -c \
         "set -e; \
          pushd /hopsan/code; \
          ./packaging/fixPythonShebang.sh ./ 3
          pushd /hopsan/code/dependencies; \
          ./setupAll.sh; \
          popd; \
          ./packaging/prepareSourceCode.sh /hopsan/code /hopsan/code \
                                           ${base_version} ${release_revision} ${full_version_name} \
                                           true false; \
          popd; \
          pushd /hopsan/build; \
          source /hopsan/code/dependencies/setHopsanBuildPaths.sh; \
          echo HOPSAN_BUILD_QT_QMAKE \${HOPSAN_BUILD_QT_QMAKE}; \
          \${HOPSAN_BUILD_QT_QMAKE} /hopsan/code/HopsanNG.pro -r -spec linux-g++ -config release; \
          make -j8; \
          popd; \
          pushd /hopsan/code; \
          packaging/copyInstallHopsan.sh ./ /hopsan/install; \
          if [[ \"$do_test\" == \"true\" ]]; then \
              export QT_QPA_PLATFORM=offscreen; \
              # Using TRAVIS_OS_NAME to prevent gui test from running, it does not work inside container for unknown reason
              export TRAVIS_OS_NAME=osx; \
              ./runUnitTests.sh; \
              ./runValidationTests.sh; \
          fi; \
          popd; \
          echo Build Done"

    pushd "${host_package_output_dir}"
    package_dir_name=hopsan-${name}${tag}-${full_version_name}
    package_file_name=${package_dir_name}.tar.gz
    rm -rf "${package_dir_name}"
    rm -rf "${package_file_name}"
    cp -rv "${host_install_dir}" "${package_dir_name}"
    tar -czf "${package_file_name}" --owner=0 --group=0 "${package_dir_name}"
    rm -rf "${package_dir_name}"
    popd
    echo "Done packaging: ${host_package_output_dir}/${package_file_name}"

else
    sudo docker run --user $(id -u):$(id -g) \
         --mount type=bind,src=${host_deps_cache},dst=/hopsan/deps \
         --mount type=bind,src=${host_code_dir},dst=/hopsan/code \
         --mount type=bind,src=${host_build_dir},dst=/hopsan/build \
         --mount type=bind,src=${host_install_dir},dst=/hopsan/install \
         --tty  --interactive --name ${image_name}-runner --entrypoint /bin/bash --rm ${image_name}
fi
