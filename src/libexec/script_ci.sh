#!/bin/sh

sudo mkdir /etc/resolver/
echo "nameserver 192.168.50.4.53" | sudo tee /etc/resolver/dev.azk.io
./bin/azk nvm node -e "require('azk').meta.set('tracker_permission', false);"
./bin/azk agent start
./src/libexec/script_ci.sh
./bin/azk nvm npm run test:slow
