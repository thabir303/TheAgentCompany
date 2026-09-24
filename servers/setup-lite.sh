#!/bin/bash
# Lightweight server setup: start only ownCloud and/or RocketChat and skip
# GitLab and Plane.
#
# The GitLab image alone is ~12 GB compressed, so skipping it (and Plane) saves
# most of the disk space the full setup needs. Tasks whose dependencies.yml only
# lists the services started here can run as usual; list them with
#   python evaluation/generate_task_images.py --allowed-services owncloud,rocketchat
#
# Usage:
#   bash setup-lite.sh                      # ownCloud + RocketChat (default)
#   bash setup-lite.sh owncloud             # ownCloud only (smallest)
#   bash setup-lite.sh rocketchat           # RocketChat (+ NPC redis) only
#   bash setup-lite.sh --down               # stop and remove everything this script started
set -e

cd "$(dirname "$0")"

PROJECT=theagentcompany
API_SERVER_IMAGE=ghcr.io/theagentcompany/servers-api-server:1.0.0
# docker-compose.yml references GITLAB_PORT even when GitLab is not started
export GITLAB_PORT=${GITLAB_PORT:-8929}

if ! docker compose version >/dev/null 2>&1; then
    echo "Error: docker compose is not installed or docker daemon is not running"
    exit 1
fi

if [ "$1" = "--down" ]; then
    docker rm -f api-server >/dev/null 2>&1 || true
    docker compose -p $PROJECT down -v
    exit 0
fi

SERVICES=("$@")
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=(owncloud rocketchat)
fi

COMPOSE_SERVICES=()
for service in "${SERVICES[@]}"; do
    case "$service" in
        owncloud)
            COMPOSE_SERVICES+=(owncloud owncloud-collabora)
            ;;
        rocketchat)
            # redis-stack + npc data population hold the NPC (sotopia) profiles
            COMPOSE_SERVICES+=(rocketchat mongodb redis-stack redis-stack-npc-data-population)
            ;;
        *)
            echo "Unknown service: $service (supported: owncloud, rocketchat)"
            exit 1
            ;;
    esac
done

echo "Starting services: ${COMPOSE_SERVICES[*]}"
docker compose -p $PROJECT up -d "${COMPOSE_SERVICES[@]}"

# The api-server is the controller that every task's /utils/init.sh talks to
# (reset + health check on port 2999). SKIP_SETUP=True stops it from running
# `make start-all`, which would pull and start GitLab and Plane.
echo "Starting api-server (SKIP_SETUP=True)..."
docker rm -f api-server >/dev/null 2>&1 || true
docker run -d \
    --name api-server \
    --network host \
    --restart always \
    -e SKIP_SETUP=True \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $API_SERVER_IMAGE

echo "Waiting for api-server on port 2999..."
until curl -s -o /dev/null localhost:2999; do
    sleep 5
done

for service in "${SERVICES[@]}"; do
    if [ "$service" = "rocketchat" ]; then
        # load the pre-baked RocketChat data (users, channels, messages)
        curl -s -X POST localhost:2999/api/reset-rocketchat
        echo
    fi
done

for service in "${SERVICES[@]}"; do
    until curl -s -o /dev/null -w "%{http_code}" localhost:2999/api/healthcheck/$service | grep -q "200"; do
        echo "Waiting for $service to be ready..."
        sleep 10
    done
    echo "$service is ready!"
done

echo "Lite setup finished. Running services: ${SERVICES[*]}"
echo "Only run tasks whose dependencies.yml is covered by these services;"
echo "tasks that need gitlab or plane will hang in init.sh waiting for them."
