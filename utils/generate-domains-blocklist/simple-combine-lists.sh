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
trim_string_front() {
    # Usage: trim_string "   example   string"

    # Remove all leading white-space.
    # '${1%%[![:space:]]*}': Strip everything but leading white-space.
    # '${1#${XXX}}': Remove the white-space from the start of the string.
    trim=${1#"${1%%[![:space:]]*}"}
    say "$trim"
}

if [ "$1" = "debug" ]; then
	shift
	DEBUG=0
elif [ "$4" = "debug" ]; then
	DEBUG=0
else
	DEBUG=1
fi

THIS_NAME=$(basename "$0"); readonly THIS_NAME
THIS_DIR=$(dirname "$0"); readonly THIS_DIR
message() {
	say "[$THIS_NAME] $1"
}
warn() {
	message "WARNING: $1" >&2
}
fatal_exit() {
	message "FATAL: $1" >&2
	exit "${2:-1}"
}
debug() {
	[ $DEBUG -eq 0 ] || return
	message "DEBUG: $1"
}

if [ -z "$3" ]; then
	message "Usage: $THIS_NAME <config_file> <output_block_file> <output_allow_file>" >&2
	exit 2
fi
debug "Called with: '$1', '$2', '$3'"

can_write() {
	[ -w "$1" ] && return 0
	dir=$(dirname "$1")
	[ ! -e "$1" ] && [ -d "$dir" ] && [ -w "$dir" ] && [ -x "$dir" ] && return 0
	return 1
}

[ -r "$1" ] || fatal_exit "Couldn't read config file ($1)." 3
can_write "$2" || fatal_exit "Couldn't write to output blocklist file ($2)." 3
can_write "$3" || fatal_exit "Couldn't write to output allowlist file ($3)." 3

for cmd in cat mktemp mv; do
	cmd_exists $cmd || fatal_exit "The command $cmd is not available." 4
done

downloader=
for cmd in curl wget; do
	if cmd_exists $cmd; then
		downloader=$cmd
		debug "Using downloader $downloader"
		break
	fi
done
[ -n "$downloader" ] || fatal_exit "Neither curl nor wget is available." 4

download() {
	if [ $downloader = "curl" ]; then
		curl -L --progress-bar "$1"
	else
		wget -O - "$1"
	fi
}

process_line() {
	protocol=${1%%:*}
	if [ "$protocol" = "file" ]; then
		fpath=${1#file:}
		[ "${fpath%%/*}" = "$fpath" ] && fpath="$THIS_DIR/$fpath"
		[ -r "$fpath" ] || fatal_exit "Couldn't read $2 file: $fpath" 3
		cat "$fpath"
	elif [ "$protocol" = "$1" ] || [ "${1#"$protocol"://}" = "$1" ]; then
		fatal_exit "References to allow- and blocklists must be either of the form 'file:<filepath>' \
or a URL including protocol." 5
	else
		download "$1" || fatal_exit "Failed to download $2 file: $1" 6
	fi
	say "" # make sure there's a trailing newline
}

section=0
tmpdir=$(mktemp -d) || fatal_exit "Couldn't create temp working directory." 3
while IFS='' read -r line || [ -n "$line" ]; do
	debug "Read line: '$line'"
	line=$(trim_string_front "$line")
	[ -z "${line%%#*}" ] && continue # skip comments
	case $section in
		0)
			if [ "$line" = "[block]" ]; then
				section=1
			else
				fatal_exit "Found a non-comment line before the [block] section of the config file: $line" 5
			fi
			;;
		1)
			if [ "$line" = "[allow]" ]; then
				section=2
				continue
			fi
			process_line "$line" "blocklist" >> "$tmpdir/block.txt"
			;;
		2)
			process_line "$line" "allowlist" >> "$tmpdir/allow.txt"
			;;
	esac
done < "$1"

debug "Moving files into place."
# -f: Overwrite existing file without prompting
mv -f "$tmpdir/block.txt" "$2" || fatal_exit "Failed to write blocklist: $2" 3
mv -f "$tmpdir/allow.txt" "$3" || fatal_exit "Failed to write allowlist: $3" 3

cmd_exists rm && rm -r "$tmpdir" # There's no -d in busybox rm
