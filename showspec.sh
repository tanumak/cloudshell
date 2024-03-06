#!/bin/bash

cpus=$(grep processor /proc/cpuinfo | tail -1 | awk '{print $3+1}')
memory=$(grep MemTotal /proc/meminfo | awk '{print int($2/1000/1000)}')

echo $cpus cpu, $memory gb memory
