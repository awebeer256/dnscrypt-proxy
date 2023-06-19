#!/usr/bin/env bash
# SPDX-License-Identifier: ISC

# A port of generate-domains-blocklist.py

# Reminder: Bash's =~ operator uses POSIX Extended Regular Expressions

RX_COMMENT='^(#|$)'; readonly RX_COMMENT

# This constant is both defined and used in sort of the inverse way here as
# 'rx_comment' in the python code is used. The effect is the same: to remove
# inline comments.
RX_HAS_INLINE_COMMENT='^(.+)[[:space:]]*#[[:space:]]*[a-z0-9-].*$'
readonly RX_HAS_INLINE_COMMENT

RX_TRUSTED='^([*a-z0-9.-]+)[[:space:]]*(@[^[:space:]]+)?$'; readonly RX_TRUSTED
RX_TIMED='.+[[:space:]]*@[^[:space:]]+$'; readonly RX_TIMED

# https://github.com/dylanaraps/pure-bash-bible
trim_string() {
	# Usage: trim_string "   example   string    "
	: "${1#"${1%%[![:space:]]*}"}"
	: "${_%"${_##*[![:space:]]}"}"
	printf '%s\n' "$_"
}

parse_trusted_list() {
	local -a names=()
	local -a time_restrictions=()
	local -a globs=()
	local -a RX_SET=("$RX_TRUSTED"); readonly RX_SET
	while IFS='' read -r line || [ -n "$line" ]; do
		line=$(trim_string "$line"); line=${line,,}
		[[ $line =~ $RX_COMMENT ]] && continue
		
		if [[ $line =~ $RX_HAS_INLINE_COMMENT ]]; then
			line=$(trim_string "${BASH_REMATCH[1]}")
		fi
		# TODO if is_glob...
	done < <(echo "$1")
	# TODO return ...
}

is_glob() {
	local maybe_glob=1
	local length=${#1}
	local lengthm1=; ((lengthm1=length-1))
	for ((i=0; i<length; i++)); do
		local c=${1:$i:1}
		if [ "$c" = "?" ] || [ "$c" = "[" ]; then
			maybe_glob=0; break
		elif [ "$c" = "*" ] && [ $i -ne 0 ]; then
			local im1=; ((im1=i-1))
			if [ $i -lt $lengthm1 ] || [ "${1:$im1:1}" = "." ]; then
				maybe_glob=0; break
			fi
		fi
	done
	[ $maybe_glob -ne 0 ] && return 1
	# TODO return 0 if and only if it's a valid glob
}
