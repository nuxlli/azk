#!/bin/bash

# install libnss-resolver
sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 022856F6D78159DF43B487D5C82CF0628592D2C9
echo "deb [arch=amd64] http://repo.azukiapp.com trusty main" | sudo tee /etc/apt/sources.list.d/azuki.list
sudo apt-get update -y
sudo apt-get install libnss-resolver -y

# /etc/resolver/dev.azk.io
sudo mkdir -p /etc/resolver
sudo touch /etc/resolver/dev.azk.io
export docker_ip=`/sbin/ip -4 -o addr | grep "docker0" | awk '{gsub(/\/.*/,"",$4); print $4}'`
echo "nameserver ${docker_ip}:53" | sudo tee -a /etc/resolver/dev.azk.io
