#!/usr/bin/env bash

#---------CHANGE THIS FOR YOUR DMENU CLIENT----------------

dmenu=(fuzzel --dmenu)

#----------------------------------------------------------

DELIM=$'\t::\t'
ZWS=$'\u200b'

#get our raw input
clients=$(hyprctl clients)

windows_raw=$(echo "$clients" | grep Window)
titles_raw=$(echo "$clients" | grep initialTitle) 
workspace_raw=$(echo "$clients" | grep workspace) 
focus_history_raw=$(echo "$clients" | grep focusHistoryID) 

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

for idx in "${order[@]}"; do
  disp="${titles[idx]:-${windows[idx]}}"
  disp="${disp:-${winids[idx]}}"

  n=$(( ${seen["$disp"]:-0} + 1 )); seen["$disp"]=$n
  tag=""
  for ((k=1; k<n; k++)); do tag+="$ZWS"; done

  pretty+=("$disp$tag")                         # visible to fuzzel
  wire+=("$disp$tag$DELIM${winids[idx]}")       # carries the id
done

choice=$(printf '%s\n' "${pretty[@]}" | "${dmenu[@]}")
[[ -z $choice ]] && exit 0

sel_idx=-1
for j in "${!pretty[@]}"; do
  [[ ${pretty[j]} == "$choice" ]] && { sel_idx=$j; break; }
done
(( sel_idx >= 0 )) || { echo "selection mapping failed" >&2; exit 1; }

selected_id=${wire[sel_idx]##*${DELIM}}

hyprctl dispatch focuswindow "address:0x$selected_id" \
  || hyprctl dispatch focuswindow "address:$selected_id" \
  || { echo "No such window ($selected_id)" >&2; exit 1; }
