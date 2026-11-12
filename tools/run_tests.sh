#!/bin/bash
# usage: runtests.sh <logdir> [tests...]   Each test gets its own user:// (XDG_DATA_HOME), so saves do not collide.
cd "$(dirname "$0")/.."
L=$1; shift; mkdir -p $L
T="$@"; [ -z "$T" ] && T="run_presets campaign_test diplomacy_test waypoint_test fuel_test structures_test escort_test move_test weather_test orders_test nuke_test sight_test salvage_test flag_test aux_test sub_test origins_test review_test tales_test"
printf "%s\n" $T | xargs -P 4 -I{} bash -c 's=$(date +%s); mkdir -p '$L'/ud_{}; XDG_DATA_HOME='$L'/ud_{} timeout 2400 godot --headless --path godot res://tests/{}.tscn > '$L'/{}.log 2>&1; echo "{} exit=$? $(( $(date +%s)-s ))s errs=$(grep -c "SCRIPT ERROR" '$L'/{}.log) fail=$(grep -c "^FAIL\|FAILED" '$L'/{}.log)"' | tee $L/summary.txt
