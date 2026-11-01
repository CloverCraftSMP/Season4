#!/usr/bin/env bash
set -euo pipefail

LOG_LEVEL="${LOG_LEVEL:-INFO}" # DEBUG, INFO, WARN, ERROR, FATAL
LOG_FILE="${LOG_FILE:-}"
LOG_USE_COLOR="${LOG_USE_COLOR:-true}"

declare -A LOG_LEVELS=(
    ["DEBUG"]=10
    ["INFO"]=20
    ["WARN"]=30
    ["ERROR"]=40
    ["FATAL"]=50
)

if [[ "$LOG_USE_COLOR" == "true" && -t 2 ]]; then
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_DEBUG="\033[36m"   # Cyan
    readonly COLOR_INFO="\033[32m"    # Green
    readonly COLOR_WARN="\033[33m"    # Yellow
    readonly COLOR_ERROR="\033[31m"   # Red
    readonly COLOR_FATAL="\033[35m"   # Magenta
else
    readonly COLOR_RESET=""
    readonly COLOR_DEBUG=""
    readonly COLOR_INFO=""
    readonly COLOR_WARN=""
    readonly COLOR_ERROR=""
    readonly COLOR_FATAL=""
fi

_log() {
    local level="$1"
    shift
    local message="$*"
    
    local current_threshold="${LOG_LEVELS[$LOG_LEVEL]}"
    local msg_level="${LOG_LEVELS[$level]}"

    if (( msg_level < current_threshold )); then
        return 0
    fi

    local timestamp
    timestamp="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    
    local file_output="[$timestamp] [$level] $message"
    
    local color_var="COLOR_$level"
    local term_output="[$timestamp] [${!color_var}$level${COLOR_RESET}] $message"

    echo -e "$term_output" >&2

    if [[ -n "$LOG_FILE" ]]; then
        echo "$file_output" >> "$LOG_FILE"
    fi

    if [[ "$level" == "FATAL" ]]; then
        exit 1
    fi
}

log_debug() { _log "DEBUG" "$@"; }
log_info()  { _log "INFO" "$@"; }
log_warn()  { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }
log_fatal() { _log "FATAL" "$@"; }