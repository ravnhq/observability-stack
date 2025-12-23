#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://localhost:3000}"
ITERATIONS="${ITERATIONS:-50}"
CONCURRENCY="${CONCURRENCY:-5}"

echo "BASE_URL=$BASE_URL"
echo "ITERATIONS=$ITERATIONS CONCURRENCY=$CONCURRENCY"

# tRPC v11: /trpc/<procedure>
# hello is a query; boom is a mutation that errors (to generate error metrics)

run_one() {
  i="$1"

  # success queries
  curl -fsS "$BASE_URL/trpc/hello?input=%7B%22name%22%3A%22nestjs%22%7D" >/dev/null

  # 1 out of 10 requests fails on purpose
  if [ $((i % 10)) -eq 0 ]; then
    curl -sS -X POST "$BASE_URL/trpc/boom" -H 'content-type: application/json' -d '{}' >/dev/null || true
  fi
}

i=1
while [ "$i" -le "$ITERATIONS" ]; do
  j=0
  while [ "$j" -lt "$CONCURRENCY" ] && [ "$i" -le "$ITERATIONS" ]; do
    run_one "$i" &
    j=$((j + 1))
    i=$((i + 1))
  done
  wait
  echo "sent up to $((i - 1))"
  sleep 0.1
done

echo "done"
