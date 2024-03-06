#!/bin/bash

set -e
cd $(dirname $(readlink -f $0))

if [ ! -z $1 ]; then
  rm -rf gs-spring-boot-docker
  docker rmi java-app:stable
  exit 0
fi

for c in docker java mvn; do
  which $c || (echo "$c not found" && exit 1)
done

if [ "$JAVA_HOME" == "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
  if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  else
    echo "java 17 not found"
    exit 1
  fi
fi

# spring-boot app
if [ ! -d gs-spring-boot-docker ]; then
  git clone --depth 1 https://github.com/spring-guides/gs-spring-boot-docker.git
  cp -p Dockerfile gs-spring-boot-docker/complete/Dockerfile
  cp -p Application.java gs-spring-boot-docker/complete/src/main/java/hello/Application.java
fi
pushd gs-spring-boot-docker/complete
mvn --batch-mode --update-snapshots verify
mkdir -p target/extracted
java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted
docker build -t java-app:stable .
popd
docker image ls java-app
