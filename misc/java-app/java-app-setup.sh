#!/bin/bash

set -e
cd $(dirname $(readlink -f $0))

if [ ! -z $1 ]; then
  rm -rf gs-spring-boot-docker
  docker rmi java-app:latest
  exit 0
fi

for c in docker java mvn; do
  which $c || (echo "$c not found" && exit 1)
done

# spring-boot app
if [ ! -d gs-spring-boot-docker ]; then
  git clone --depth 1 https://github.com/spring-guides/gs-spring-boot-docker.git
  cp -p Dockerfile gs-spring-boot-docker/complete/Dockerfile
fi
pushd gs-spring-boot-docker/complete
mvn --batch-mode --update-snapshots verify
mkdir -p target/extracted
java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted
docker build -t java-app:latest .
popd
docker image ls java-app
