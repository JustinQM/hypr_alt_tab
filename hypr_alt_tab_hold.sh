#!/usr/bin/env bash

#---------CHANGE THIS FOR YOUR DMENU CLIENT----------------

dmenu=(fuzzel --dmenu)

#----------------------------------------------------------

DELIM=$'\t::\t'
ZWS=$'\u200b'

#get our raw input
clients=$(hyprctl clients)

desktop_icon()
{
    local class="$1" bin="$2" f icon
    for dir in "$HOME/.local/share/applications" /usr/share/applications; do
        #1
        [[ -f "$dir/${class}.desktop" ]] && f=$dir/${class}.desktop
        #2
        [[ -z $f ]] && f=$(grep -FIl "StartupWMClass=$class" "$dir"/*.desktop 2>/dev/null | head -n1)

        if [[ -n $f ]]; then
            icon=$(awk -F= '/^Icon=/ {print $2; exit}' "$f")
            [[ -n $icon ]] && { printf '%s\n' "$icon"; return 0;}
        fi
    done
    printf '%s\n' "$bin"
}

windows_raw=$(echo "$clients" | grep Window)
titles_raw=$(echo "$clients" | grep initialTitle)
workspace_raw=$(echo "$clients" | grep workspace)
focus_history_raw=$(echo "$clients" | grep focusHistoryID)
class_raw=$(echo "$clients" | grep -E '^\s*class:\s')
pid_raw=$(echo "$clients" | grep -E '^\s*pid:\s')

#clean it up into parallel arrays
windows=()
winids=()
while IFS= read -r line; do
    id=${line#Window }
    id=${id%% *}
    s=${line#*-> }
    s=${s%:}
    windows+=("$s")
    winids+=("$id")
done <<< "$windows_raw"

titles=()
while IFS= read -r line; do
    s=${line#*: }
    titles+=("$s")
done <<< "$titles_raw"

workspaces=()
while IFS= read -r line; do
    s=${line#*\(}
    s=${s%%\)}
    workspaces+=("$s")
done <<< "$workspace_raw"

focus_history=()
while IFS= read -r line; do
    s=${line#*: }
    focus_history+=("$s")
done <<< "$focus_history_raw"

class=()
while IFS= read -r line; do
    s=${line#*: }
    class+=("$s")
done <<< "$class_raw"

pid=()
while IFS= read -r line; do
    s=${line#*: }
    pid+=("$s")
done <<< "$pid_raw"

#sort names by focus history
order=()
while IFS=$'\t' read -r _ idx; do order+=("$idx"); done < <(
  for i in "${!windows[@]}"; do
    printf '%s\t%s\n' "${focus_history[i]}" "$i"
  done | LC_ALL=C sort -n -k1,1
)

declare -A seen
pretty=()
wire=()
icons=()

for idx in "${order[@]}"; do
  disp="${titles[idx]:-${windows[idx]}}"
  disp="${disp:-${winids[idx]}}"

  n=$(( ${seen["$disp"]:-0} + 1 )); seen["$disp"]=$n
  tag=""
  for ((k=1; k<n; k++)); do tag+="$ZWS"; done

  #get icons
  c="${class[idx]}"
  c="${c,,}" #make lowercase

  exe=$(readlink -f "/proc/$pids[idx]}/exe" 2>/dev/null || true)
  bin="${exe##*/}"

  icon="$c"
  [[ -z $icon ]] && icon="$bin"

  d_icon=$(desktop_icon "$c" "$bin")
  [[ -n $d_icon ]] && icon="$d_icon"

  icons+=("$icon")
  #end icons code

  pretty+=("$disp$tag")                         # visible to fuzzel
  wire+=("$disp$tag$DELIM${winids[idx]}")       # carries the id
done

choice=$({
    for j in "${!pretty[@]}"; do
        printf '%s\0icon\x1f%s\n' "${pretty[j]}" "${icons[j]}"
    done
} | "${dmenu[@]}")
[[ -z $choice ]] && exit 0

sel_idx=-1
for j in "${!pretty[@]}"; do
  [[ "${pretty[j]}" == "$choice" ]] && { sel_idx=$j; break; }
done
(( sel_idx >= 0 )) || { echo "selection mapping failed" >&2; exit 1; }

selected_id=${wire[sel_idx]##*${DELIM}}

hyprctl dispatch focuswindow "address:0x$selected_id" \
  || hyprctl dispatch focuswindow "address:$selected_id" \
  || { echo "No such window ($selected_id)" >&2; exit 1; }
