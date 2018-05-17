#!/usr/bin/env bash

docker build -t apside-pg .
docker run --name apside-pg -e POSTGRES_PASSWORD=apside -p 5432:5432 -d apside-pg