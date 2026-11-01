#!/usr/bin/env bash

INPUT_FILE="quotes.txt"
OUTPUT_FILE="main.conf"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found!"
    exit 1
fi

MAX_MOTD_PIXELS=270
SPACE_TOTAL_WIDTH=5

get_char_width() {
    local char="$1"
    case "$char" in
        "!") echo 1 ;;
        "'"|","|"."|":"|";"|"|") echo 1 ;;
        "\`") echo 2 ;;
        "\""|"("|")"|"*"|"["|"]") echo 3 ;;
        "<"|">"|"f"|"k"|"t"|"{"|"}") echo 4 ;;
        " ") echo 4 ;;
        "@") echo 6 ;;
        *) echo 5 ;;
    esac
}

get_line_pixel_width() {
    local text="$1"
    
    local clean_text
    clean_text=$(echo -n "$text" | sed -E 's/<[^>]*>//g' | sed -E 's/[&§][0-9a-fk-orA-FK-OR]//g')
    
    local is_bold=0
    if [[ "${text},," =~ .*(\<bold\>|\<b\>).* ]]; then
        is_bold=1
    fi
    
    local total_width=0
    local len=${#clean_text}
    
    for (( i=0; i<len; i++ )); do
        local char="${clean_text:i:1}"
        local base_width
        base_width=$(get_char_width "$char")
        
        if [[ $is_bold -eq 1 && "$char" != " " ]]; then
            base_width=$((base_width + 1))
        fi
        
        total_width=$((total_width + base_width))
        
        if (( i < len - 1 )); then
            total_width=$((total_width + 1))
        fi
    done
    
    echo "$total_width"
}

get_center_padding_spaces() {
    local full_line_text="$1"
    local text_width
    text_width=$(get_line_pixel_width "$full_line_text")
    
    if (( text_width >= MAX_MOTD_PIXELS )); then
        echo 0
        return
    fi
    
    local remaining_pixels=$(( (MAX_MOTD_PIXELS - text_width) / 2 ))
    local needed_spaces=$(( remaining_pixels / SPACE_TOTAL_WIDTH ))
    echo "$needed_spaces"
}

LINE1="<b><dark_gray>//</dark_gray></b>     <b><gradient:#00aa00:#27aa6b>CloverCraft</gradient></b>     <b><dark_gray>//</dark_gray></b>     <b><gradient:#507c94:#ff386d>Season 4</gradient></b>       <b><dark_gray>//</dark_gray></b>"

cat << EOF > "$OUTPUT_FILE"
# generated via script, DO NOT EDIT MANUALLY
motd-enabled=true

motds=[
EOF

first=true
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "    }," >> "$OUTPUT_FILE"
    fi
    
    LINE2_BASE="<b><dark_gray>//</dark_gray></b><bold><white>${line}</white></bold><b><dark_gray>//</dark_gray></b>"
    
    needed_spaces=$(get_center_padding_spaces "$LINE2_BASE")
    
    left_spaces=$(( needed_spaces / 2 ))
    right_spaces=$(( needed_spaces - left_spaces ))
    
    left_pad=$(printf '%*s' "$left_spaces" "")
    right_pad=$(printf '%*s' "$right_spaces" "")
    
    LINE2_FINAL="${left_pad}<b><dark_gray>//</dark_gray></b>${right_pad}<bold><white>${line}</white></bold>${right_pad}<b><dark_gray>//</dark_gray></b>"
    
    cat << EOF >> "$OUTPUT_FILE"
    {
        icon=random
        line1="${LINE1}"
        line2="${LINE2_FINAL}"
EOF
done < "$INPUT_FILE"

cat << EOF >> "$OUTPUT_FILE"
    }
]
EOF