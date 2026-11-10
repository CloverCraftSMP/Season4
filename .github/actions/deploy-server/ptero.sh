#!/usr/bin/env bash
#
#   PTERO_PANEL_URL  Panel base URL
#   PTERO_API_KEY    Client API key
#   PTERO_SERVER_ID  Server identifier
#
#   power <start|stop|restart|kill>       Send a power signal
#   command <console command>            Run a console command (e.g. "save-all flush")
#   backup <name> [output-dir]           Create, wait for and download a backup
#   prune [keep]                         Delete stale, pipeline-owned backups
#   file-get <remote path> <local file>  Download a file from the server
#                                        (exit 1 if it is missing/unreadable)
#   file-put <remote path> <local file>  Upload a file to the server
#
#   PTERO_BACKUP_KEEP      Backups created by this pipeline to keep (default 5)
#   PTERO_BACKUP_TIMEOUT   Seconds to wait for a backup (default 1800)

set -euo pipefail

: "${PTERO_PANEL_URL:?PTERO_PANEL_URL is required}"
: "${PTERO_API_KEY:?PTERO_API_KEY is required}"
: "${PTERO_SERVER_ID:?PTERO_SERVER_ID is required}"

API_BASE="${PTERO_PANEL_URL%/}/api/client/servers/${PTERO_SERVER_ID}"
BACKUP_PREFIX="pre-release-"
BACKUP_KEEP="${PTERO_BACKUP_KEEP:-5}"
BACKUP_TIMEOUT="${PTERO_BACKUP_TIMEOUT:-1800}"

log() { printf 'ptero: %s\n' "$*" >&2; }
die() {
	printf 'ptero: error: %s\n' "$*" >&2
	exit 1
}

api_request() {
	local method="$1" path="$2" out="$3"
	shift 3

	API_STATUS=$(curl \
		--silent --show-error \
		--request "$method" \
		--output "$out" \
		--write-out '%{http_code}' \
		--header "Authorization: Bearer ${PTERO_API_KEY}" \
		--header "Accept: Application/vnd.pterodactyl.v1+json" \
		"$@" \
		"${API_BASE}${path}") || {
		rm -f "$out"
		die "network error while calling ${method} ${path}"
	}
}

api_call() {
	local method="$1" path="$2" body="${3:-}"
	local file
	local -a extra=(--header "Content-Type: application/json")

	if [[ -n "$body" ]]; then
		extra+=(--data "$body")
	fi

	file=$(mktemp)
	api_request "$method" "$path" "$file" "${extra[@]}"
	API_BODY=$(cat "$file")
	rm -f "$file"
}

api_ok() { ((API_STATUS < 400)); }

api_error() {
	jq -c '.errors // .' <<<"$API_BODY" 2>/dev/null || printf '%s' "$API_BODY"
}

urlencode() { jq -rn --arg x "$1" '$x | @uri'; }

prune_backups() {
	local keep="${1:-$BACKUP_KEEP}" victims uuid

	api_call GET "/backups?per_page=100"
	api_ok || die "listing backups failed: $(api_error)"

	victims=$(jq -r --arg prefix "$BACKUP_PREFIX" --argjson keep "$keep" '
        [ .data[]?.attributes
          | select(.is_locked != true)
          | select(.name | startswith($prefix))
        ]
        | sort_by(.created_at)
        | if length > $keep then .[0:(length - $keep)][].uuid else empty end
    ' <<<"$API_BODY")

	if [[ -z "$victims" ]]; then
		log "no stale backups to prune"
		return 0
	fi

	while read -r uuid; do
		[[ -z "$uuid" ]] && continue
		api_call DELETE "/backups/$uuid"
		if api_ok; then
			log "deleted stale backup $uuid"
		else
			log "warning: could not delete backup $uuid: $(api_error)"
		fi
	done <<<"$victims"
}

cmd_backup() {
	local name="${1:?backup name is required}"
	local out_dir="${2:-.}"
	local payload uuid url dest state deadline

	mkdir -p "$out_dir"
	prune_backups

	payload=$(jq -nc --arg name "$name" '{name: $name, is_locked: false}')
	log "creating backup '$name'"
	api_call POST /backups "$payload"

	if ! api_ok && grep -q TooManyBackupsException <<<"$API_BODY"; then
		log "server is at its backup limit - pruning down to the newest backup"
		prune_backups 1
		api_call POST /backups "$payload"
	fi
	api_ok || die "creating backup failed: $(api_error)"

	uuid=$(jq -r '.attributes.uuid // empty' <<<"$API_BODY")
	[[ -n "$uuid" ]] || die "panel did not return a backup id: $API_BODY"

	log "waiting for backup $uuid to finish (timeout ${BACKUP_TIMEOUT}s)"
	deadline=$((SECONDS + BACKUP_TIMEOUT))
	while :; do
		api_call GET "/backups/$uuid"
		api_ok || die "checking backup $uuid failed: $(api_error)"

		state=$(jq -r '.attributes.is_successful' <<<"$API_BODY")
		case "$state" in
		true) break ;;
		false) die "backup $uuid failed on the panel: $(api_error)" ;;
		esac

		((SECONDS < deadline)) || die "timed out after ${BACKUP_TIMEOUT}s waiting for backup $uuid"
		sleep 10
	done

	api_call GET "/backups/$uuid/download"
	api_ok || die "requesting a download url failed: $(api_error)"

	url=$(jq -r '.attributes.url // empty' <<<"$API_BODY")
	[[ "$url" == http* ]] || die "panel did not return a download url"

	dest="$out_dir/$name.tar.zst"
	curl --silent --show-error --fail --location --retry 3 --output "$dest" "$url" ||
		die "downloading the backup failed"
	log "downloaded $dest ($(du -h "$dest" | cut -f1))"
}

cmd_command() {
	local command="$*"
	[[ -n "$command" ]] || die "a console command is required"
	api_call POST /commands "$(jq -nc --arg command "$command" '{command: $command}')"
	api_ok || die "sending the console command failed: $(api_error)"
	log "ran console command: $command"
}

cmd_file_get() {
	local remote="${1:?remote path is required}"
	local local_file="${2:?local file is required}"
	local tmp

	tmp=$(mktemp)
	api_request GET "/files/contents?file=$(urlencode "$remote")" "$tmp"

	if ((API_STATUS == 404)); then
		rm -f "$tmp"
		log "$remote does not exist on the server"
		return 1
	fi

	if ! api_ok; then
		API_BODY=$(head -c 2000 "$tmp")
		rm -f "$tmp"
		log "warning: reading $remote failed with status $API_STATUS: $(api_error)"
		return 1
	fi

	if [[ ! -s "$tmp" ]]; then
		rm -f "$tmp"
		log "warning: $remote came back empty"
		return 1
	fi

	mv "$tmp" "$local_file"
	log "read $remote -> $local_file"
}

cmd_file_put() {
	local remote="${1:?remote path is required}"
	local local_file="${2:?local file is required}"
	local out

	[[ -f "$local_file" ]] || die "$local_file does not exist"

	out=$(mktemp)
	api_request POST "/files/write?file=$(urlencode "$remote")" "$out" \
		--header "Content-Type: text/plain" \
		--data-binary "@${local_file}"
	API_BODY=$(cat "$out")
	rm -f "$out"

	api_ok || die "writing $remote failed: $(api_error)"
	log "wrote $remote (from $local_file)"
}

cmd_power() {
	local signal="${1:?signal is required}"
	case "$signal" in
	start | stop | restart | kill) ;;
	*) die "unsupported power signal '$signal'" ;;
	esac

	api_call POST /power "$(jq -nc --arg signal "$signal" '{signal: $signal}')"
	api_ok || die "power $signal failed: $(api_error)"
	log "sent '$signal' to $PTERO_SERVER_ID"
}

main() {
	case "${1:-}" in
	power)
		shift
		cmd_power "$@"
		;;
	command)
		shift
		cmd_command "$@"
		;;
	backup)
		shift
		cmd_backup "$@"
		;;
	prune)
		shift
		prune_backups "$@"
		;;
	file-get)
		shift
		cmd_file_get "$@"
		;;
	file-put)
		shift
		cmd_file_put "$@"
		;;
	*) die "unknown command '${1:-}' (see the header of this script for usage)" ;;
	esac
}

main "$@"
