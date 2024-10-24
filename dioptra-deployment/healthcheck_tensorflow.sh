#!/bin/bash

set -euo pipefail

LOGNAME="Worker Healthcheck"

log_error() {
  echo "${LOGNAME}: ERROR -" "${@}" 1>&2
}

healthcheck_process() {
  local num_procs

  # Check if the worker process is running with the correct arguments
  if ! num_procs="$(pgrep -afc "dioptra-worker-v1 --url redis://dioptra-deployment-redis:6379/0 --results-ttl 500")"; then
    log_error "Polling of dioptra-worker-v1 with expected arguments failed."
    exit 1
  fi

  if ((num_procs != 1)); then
    log_error "Process count for dioptra-worker-v1 with expected arguments is ${num_procs} instead of 1."
    exit 1
  fi
}

# Python script to check Redis connection and queue existence
check_redis_connection() {
  python3 << EOF
import sys
import redis

# Try connecting to Redis and checking for the queue
try:
    redis_url = "redis://dioptra-deployment-redis:6379/0"
    queue_name = "tensorflow_cpu"  # Replace with the queue you're checking

    # Connect to Redis
    r = redis.StrictRedis.from_url(redis_url)

    # Check if Redis is responding
    if not r.ping():
        print("Redis connection failed.")
        sys.exit(1)

    # Check if the queue exists (empty or not)
    if not r.exists(queue_name):
        print(f"Queue '{queue_name}' does not exist yet (this is fine if no tasks have been added yet).")
    else:
        # If the queue exists, check if it is a valid Redis list
        if r.type(queue_name) != b'list':
            print(f"Queue '{queue_name}' is not accessible or not a valid Redis list.")
            sys.exit(1)

except redis.exceptions.ConnectionError as e:
    print(f"Redis connection error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Unexpected error: {e}")
    sys.exit(1)

print("Redis connection and queue check passed.")
EOF
}

main() {
  # Check if the worker process is running
  healthcheck_process

  # Check Redis connection and queue
  check_redis_connection
}

main
