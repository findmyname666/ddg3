#!/bin/sh
set -eu

FQDN_DEFAULT="feedduck.localhost"

# Default values
POSITIVE_COUNT=100
NEGATIVE_COUNT=100

# Docker
DB_CONTAINER_NAME="feedduck-postgres-dev"
DB_USER="postgres"
DB_NAME="feedback"

# Capture start time for verification
START_TIME=$(date -u +"%Y-%m-%d %H:%M:%S")

# Parse command line arguments
usage() {
    cat <<EOF
Usage: $0 [-c] [-f fqdn] [-p positive_count] [-n negative_count] [-h]
  -c  Container name to connect to the database (default: $DB_CONTAINER_NAME).
      If specified will connect to the database container on localhost and
      verify the feedback was submitted.
  -f  FQDN of the FeedDuck instance (default: $FQDN_DEFAULT).
  -p  Number of positive feedbacks to insert (default: 100).
  -n  Number of negative feedbacks to insert (default: 100).
  -h  Show this help message
EOF
    exit 1
}

submit() {
    curl \
        -X POST \
        --insecure \
        "$URL" \
        -d "sentiment=$1" \
        -d "message=${2:-}"
}

db_exec() {
    docker \
        exec \
        -i \
        "$db_container_name" \
        psql \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -t \
        -c "$1"
}

fqdn="$FQDN_DEFAULT"
db_container_name="$DB_CONTAINER_NAME"

while getopts "c:f:p:n:h" opt; do
    case $opt in
        c)
            db_container_name="$OPTARG"
            ;;
        f)
            fqdn="$OPTARG"
            ;;
        p)
            POSITIVE_COUNT="$OPTARG"
            ;;
        n)
            NEGATIVE_COUNT="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

URL="https://$fqdn/submit"

# Validate that counts are positive integers
if ! echo "$POSITIVE_COUNT" | grep -qE '^[0-9]+$' || [ "$POSITIVE_COUNT" -lt 0 ]; then
    echo "Error: Positive count must be a non-negative integer" >&2
    exit 1
fi

if ! echo "$NEGATIVE_COUNT" | grep -qE '^[0-9]+$' || [ "$NEGATIVE_COUNT" -lt 0 ]; then
    echo "Error: Negative count must be a non-negative integer" >&2
    exit 1
fi

# Submit positive feedbacks
echo "Submitting $POSITIVE_COUNT positive feedbacks..."
for i in $(seq 1 "$POSITIVE_COUNT"); do
    submit "positive" "This is a positive message $i"
done

# Submit negative feedbacks
echo "Submitting $NEGATIVE_COUNT negative feedbacks..."
for i in $(seq 1 "$NEGATIVE_COUNT"); do
    submit "negative" "This is a negative message $i"
done

echo "Done! Submitted '$POSITIVE_COUNT' positive and '$NEGATIVE_COUNT' negative feedbacks."

[ -n "${db_container_name:-}" ] || exit 0

# Optionally connect to database and verify
echo "Verifying feedback in database..."
db_count=$(
    db_exec "SELECT COUNT(*) FROM feedback WHERE created_at >= '$START_TIME';" \
        | grep -Eo '[0-9]+' \
        | head -n 1
)

expected_total_count=$((POSITIVE_COUNT + NEGATIVE_COUNT))

[ "$db_count" = "$expected_total_count" ] || {
    echo "Verification failed!" >&2
    echo "Database contains '$db_count' feedbacks, expected '$expected_total_count'" >&2
    exit 1
}

echo "Verification successful!"

echo "Updating feedback created_at to be in the past..."
db_exec "UPDATE feedback SET created_at = created_at - INTERVAL '1 day' WHERE created_at >= '$START_TIME';" \
    > /dev/null

echo "Done!"
