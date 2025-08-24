# !/bin/bash

direction=$1
fixed_position=$2
if [ "$direction" != "left" ] && [ "$direction" != "right" ] && [ "$direction" != "up" ] && [ "$direction" != "up" ] && [ "$direction" != "down" ] && [ "$direction" != "fixed" ]; then
  echo "Invalid direction. Use 'left', 'right', 'up', 'down' or 'fixed'."
  exit 1
fi

current_window=$(hyprctl -j activewindow)
if [ -z "$current_window" ]; then
  exit 1
fi

current_floating=$(jq -r ".floating" <<<"$current_window")
if [ "$current_floating" == "true" ]; then
  exit 1
fi

current_address=$(jq -r ".address" <<<"$current_window")
current_workspace=$(jq -r ".workspace.id" <<<"$current_window")

clients=$(hyprctl -j clients | jq -r "[.[] | select(.workspace.id == $current_workspace and .floating == false)] | sort_by(.at[0])")
first_address=$(jq -r ".[0].address" <<<"$clients")
first_width=$(jq -r ".[0].size[0]" <<<"$clients")
first_height=$(jq -r ".[0].size[1]" <<<"$clients")

monitors=$(hyprctl -j monitors)
monitor_id=$(jq -r ".monitor" <<<"$current_window")
monitor_width=$(jq ".[]|select(.id==$monitor_id)|.width"  <<<"$monitors")
monitor_height=$(jq ".[]|select(.id==$monitor_id)|.height" <<<"$monitors")

# Example, monitor_width => 3440
base=$((monitor_width / 6)) # 573
p0=$((base * 1)) # 573
p1=$((base * 2)) # 1146
p2=$((base * 3)) # 1720
p3=$((base * 4)) # 2293
p4=$((base * 5)) # 2866

checkpoints=(
  $p0
  $p1
  $p2
  $p3
  $p4
)

new_index=3
for i in {0..4}; do
  if [ "$first_width" -le "${checkpoints[$i]}" ]; then
    new_index=$((i + 1))
    break
  fi
done

if [ "$direction" == "right" ]; then
  new_index=$((new_index + 1))
elif [ "$direction" == "left" ]; then
  new_index=$((new_index - 1))
elif [ "$direction" == "up" ]; then
  new_index=3
  if [ "$first_width" == "${checkpoints[2]}" ] || [ "$current_width" == "${checkpoints[2]}" ]; then
    if [ "$first_address" == "$current_address" ]; then
      new_index=5
    else
      new_index=1
    fi
  fi
elif [ "$direction" == "down" ]; then
  if [ "$first_width" == "${checkpoints[0]}" ]; then
    new_index=5
  else
    new_index=1
  fi
elif [ "$direction" == "fixed" ]; then
  if [ "$first_address" == "$current_address" ]; then
    new_index=$fixed_position
  else
    new_index=$((6 - fixed_position))
  fi
else
  exit 1
fi

if [ "$new_index" -gt 5 ]; then
  new_index=1
elif [ "$new_index" -lt 1 ]; then
  new_index=5
fi

new_width=${checkpoints[$new_index - 1]}
delta_x=$((new_width - first_width))
delta_y=0

hyprctl dispatch resizewindowpixel $delta_x $delta_y,address:$first_address
