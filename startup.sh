#!/bin/bash

ps -ef | grep "[s]erver.rb"
ret=$?

if [[ ret -eq 0 ]]; then
  echo "You have runing server"
  exit
fi

ps -ef | grep "[w]orker.rb"
ret=$?

if [[ ret -eq 0 ]]; then
  echo "You have runing worker"
  exit
fi

echo "Starting server..."
screen -dmS mzroom_server bash -c "cd $PWD; ruby server.rb"
echo "Starting worker..."
screen -dmS mzroom_worker bash -c "cd $PWD; ruby worker.rb"
