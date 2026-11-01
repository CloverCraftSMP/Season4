#!/usr/bin/env bash
set -euo pipefail

_get_toml_val() {
    local file="$1"
    local key="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi

    awk -F'=' -v target="$key" '
        $1 ~ "^[[:space:]]*" target "[[:space:]]*$" {
            sub(/^[[:space:]]*["\x27]?/, "", $2); 
            sub(/["\x27]?[[:space:]]*(#.*)?$/, "", $2); 
            print $2;
            exit;
        }
    ' "$file"
}

load_toml_vars() {
    local file="$1"
    shift

    local root_dir="${MISE_PROJECT_ROOT:-.}"
    [[ "$file" != /* ]] && file="$root_dir/$file"

    if [ ! -f "$file" ]; then
        echo "Error: TOML file not found at $file!" >&2
        exit 1
    fi

    local pair var_name toml_key val missing=0
    for pair in "$@"; do
        var_name="${pair%%:*}"
        toml_key="${pair##*:}"
        
        val="$(_get_toml_val "$file" "$toml_key")"
        
        if [ -z "$val" ]; then
            echo "Error: Could not parse '$toml_key' from $file." >&2
            missing=1
        else
            export "$var_name"="$val"
        fi
    done

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}