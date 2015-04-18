#!/bin/bash

sudo mkdir /etc/resolver/
echo "nameserver 192.168.50.4.53" | sudo tee /etc/resolver/dev.azk.io
./bin/azk nvm node -e "require('azk').meta.set('tracker_permission', false);"

echo "" > /tmp/azk-agent-start.log
./bin/azk agent start --no-daemon > /tmp/azk-agent-start.log 2>&1 &
AGENT_PID="$!"
tail -f /tmp/azk-agent-start.log &
TAIL_PID="$!"
echo "PIDS - agent: ${AGENT_PID}, tail: ${TAIL_PID}";
until tail -1 /tmp/azk-agent-start.log | grep -q 'Agent has been successfully started.'; do
  sleep 2;
  kill -0 ${AGENT_PID} || exit 1;
done

kill -9 $TAIL_PID

./src/libexec/script_ci.sh
./bin/azk nvm npm run test:slow
