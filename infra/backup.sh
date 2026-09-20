#!/bin/sh
# A nightly dump, kept for KEEP_DAYS. Runs as its own container so it starts
# and stops with the rest of the stack.
#
# This machine failing is one thing; this machine and its backups failing
# together is the one that loses the family's history. Copy /backups off the
# server too (docs/hosting.md).
set -eu

while true; do
	stamp="$(date -u +%Y%m%dT%H%M%SZ)"
	file="/backups/family-$stamp.sql.gz"

	# To a temporary name first: a half-written dump that looks like a backup
	# is worse than an obvious gap.
	if pg_dump --no-owner | gzip > "$file.partial"; then
		mv "$file.partial" "$file"
		echo "backup: wrote $file"
	else
		rm -f "$file.partial"
		echo "backup: FAILED at $stamp" >&2
	fi

	find /backups -name 'family-*.sql.gz' -mtime "+$KEEP_DAYS" -delete

	# Once a day, from whenever the stack came up.
	sleep 86400
done
