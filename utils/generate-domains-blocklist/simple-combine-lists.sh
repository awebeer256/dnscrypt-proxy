#!/usr/bin/env sh
# SPDX-License-Identifier: ISC

cmd_exists() {
	command -v "$1" > /dev/null && return 0 || return 1
}
say() {
	printf '%s\n' "$1"
}
# https://github.com/dylanaraps/pure-sh-bible
basename() {
    # Usage: basename "path" ["suffix"]

    # Strip all trailing forward-slashes '/' from
    # the end of the string.
    #
    # "${1##*[!/]}": Remove all non-forward-slashes
    # from the start of the string, leaving us with only
    # the trailing slashes.
    # "${1%%"${}"}:  Remove the result of the above
    # substitution (a string of forward slashes) from the
    # end of the original string.
    dir=${1%"${1##*[!/]}"}

    # Remove everything before the final forward-slash '/'.
    dir=${dir##*/}

    # If a suffix was passed to the function, remove it from
    # the end of the resulting string.
    dir=${dir%"$2"}

    # Print the resulting string and if it is empty,
    # print '/'.
    say "${dir:-/}"
}
dirname() {
    # Usage: dirname "path"

    # If '$1' is empty set 'dir' to '.', else '$1'.
    dir=${1:-.}

    # Strip all trailing forward-slashes '/' from
    # the end of the string.
    #
    # "${dir##*[!/]}": Remove all non-forward-slashes
    # from the start of the string, leaving us with only
    # the trailing slashes.
    # "${dir%%"${}"}": Remove the result of the above
    # substitution (a string of forward slashes) from the
    # end of the original string.
    dir=${dir%%"${dir##*[!/]}"}

    # If the variable *does not* contain any forward slashes
    # set its value to '.'.
    [ "${dir##*/*}" ] && dir=.

    # Remove everything *after* the last forward-slash '/'.
    dir=${dir%/*}

    # Again, strip all trailing forward-slashes '/' from
    # the end of the string (see above).
    dir=${dir%%"${dir##*[!/]}"}

    # Print the resulting string and if it is empty,
    # print '/'.
    say "${dir:-/}"
}

THIS_NAME=$(basename "$0"); readonly THIS_NAME
message() {
	say "[$THIS_NAME] $1"
}
fatal_exit() {
	message "FATAL: $1" >&2
	exit "${2:-1}"
}

if [ -z "$3" ]; then
	message "Usage: $THIS_NAME <config_file> <output_block_file> \
<output_allow_file>" >&2
	exit 2
fi

can_write() {
	[ -w "$1" ] && return 0
	[ ! -e "$1" ] && [ -d "$(dirname "$1")" ] && [ -w "$(dirname "$1")" ] && \
		[ -x "$(dirname "$1")" ] && return 0
	return 1
}

[ -r "$1" ] || fatal_exit "Couldn't read config file ($1)." 3
can_write "$2" || fatal_exit "Couldn't write to output blocklist file ($2)." 3
can_write "$3" || fatal_exit "Couldn't write to output allowlist file ($3)." 3

