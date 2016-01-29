#!/bin/bash

set -xeo pipefail

GD_ENV_FILE=${1:-maza-10.2.env}


# get the local UID, and make sure we build the containers 
# with gitian user mapped to this
# ensures write access to output directories
LOCAL_USER=$(whoami)
# TBH I don't know how portable this is, 
# so, we'll bail if we don't have UID
ME=${UID}

function die {
  echo "you do not have a UID=\"${UID}\" set in your environment"
  exit 1
}
test -z ${ME} && die 
if [ "${ME}" = "0" ] ; then
  echo  "Seriously. let's make this run without root privs"
   exit 2
fi

NAMESPACE=${LOCAL_USER:-guruvan}

echo "rm -rf ${NAMESPACE} Stage2 Dockerfile clean.sh" > ./clean.sh
chmod +x ./clean.sh 


sed 's/LOCAL_UID/'${ME}'/g' Dockerfile.stage1 > Dockerfile
docker build -f Dockerfile -t ${NAMESPACE}/gitian-stage1 . 

mkdir -pv $(pwd)/${NAMESPACE}/gitian-builder 
mkdir -pv $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src
sudo chown -R  ${ME}  $(pwd)/${NAMESPACE}

#docker run -it --rm --privileged --volumes-from gitian_data  ${NAMESPACE}/gitian-stage1
docker run -it --rm --privileged -v $(pwd)/${NAMESPACE}:/data ${NAMESPACE}/gitian-stage1

mkdir Stage2

echo -e "FROM ${NAMESPACE}/gitian-stage1" > Dockerfile.stage2
echo -e "ENTRYPOINT [\"/gitian/gitian_build.sh\"]" >> Dockerfile.stage2

cp Dockerfile.stage2 Stage2
cd Stage2

docker build -f Dockerfile.stage2 -t ${NAMESPACE}/gitian-builder . 
cd ..

docker run -it --rm  --privileged --env-file ${GD_ENV_FILE}  -v $(pwd)/${NAMESPACE}/gitian-builder/gitian-builder:/gitian/gitian-builder -v $(pwd)/${NAMESPACE}/${GD_BUILD_COIN}-src:/gitian/${GD_BUILD_COIN}  ${NAMESPACE}/gitian-builder    