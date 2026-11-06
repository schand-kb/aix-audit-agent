#!/usr/bin/ksh

# Run only from an engineer-controlled trusted directory not writable by
# untrusted users. Do not run from /tmp or another shared writable directory.
# The collector creates exactly one new timestamped evidence file here.

PATH=/usr/bin:/usr/sbin:/sbin
export PATH

if [ "$#" -ne 0 ]; then
	printf '%s\n' 'This collector does not accept arguments.' >&2
	exit 2
fi

umask 077
set -C

timestamp=$(date '+%Y%m%d_%H%M%S')
timestamp_rc=$?
if [ "$timestamp_rc" -ne 0 ]; then
	printf '%s\n' 'Unable to generate an evidence filename timestamp.' >&2
	exit 1
fi

case "$timestamp" in
	[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
	*)
		printf '%s\n' 'Unable to generate an evidence filename timestamp.' >&2
		exit 1
		;;
esac

evidence_file="aix_audit_${timestamp}_$$.txt"
exec 3>&1

# Open once under noclobber, then direct both collection streams to that file.
if exec 4> "$evidence_file"; then
	:
else
	printf '%s\n' "Unable to create evidence file: $evidence_file" >&3
	exit 1
fi
exec 1>&4 2>&1

total_sections=19
successful_sections=0
failed_sections=0
unavailable_sections=0

write_section_header() {
	section_timestamp=$(date '+%Y%m%d_%H%M%S')
	timestamp_rc=$?
	if [ "$timestamp_rc" -ne 0 ] || [ -z "$section_timestamp" ]; then
		section_timestamp='UNAVAILABLE'
	fi
	printf '\nSection %s: %s\n' "$section_number" "$section_name"
	printf 'Display command: %s\n' "$display_command"
	printf 'Collection timestamp: %s\n' "$section_timestamp"
	printf '%s\n' 'Command output and stderr (captured together):'
}

record_executed_status() {
	printf 'Command return code: %s\n' "$command_rc"
	if [ "$command_rc" -eq 0 ]; then
		section_status='COLLECTED'
		successful_sections=$((successful_sections + 1))
	else
		section_status='FAILED'
		failed_sections=$((failed_sections + 1))
	fi
	printf 'Section status: %s\n' "$section_status"
}

record_unavailable_status() {
	printf '%s\n' 'Command was not executed: unavailable on the fixed PATH.'
	section_status='COMMAND NOT AVAILABLE'
	unavailable_sections=$((unavailable_sections + 1))
	printf 'Section status: %s\n' "$section_status"
}

printf '%s\n' 'AIX read-only audit evidence'
printf '%s\n' 'Collection output and command stderr are captured in this file.'
printf '%s\n' 'PERMISSION DENIED is not inferred; nonzero results are FAILED.'

section_number=1
section_name='System hostname'
display_command='hostname'
write_section_header
if command -v hostname >/dev/null 2>&1; then
	hostname
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=2
section_name='Operating system and kernel'
display_command='uname -a'
write_section_header
if command -v uname >/dev/null 2>&1; then
	uname -a
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=3
section_name='AIX service level'
display_command='oslevel -s'
write_section_header
if command -v oslevel >/dev/null 2>&1; then
	oslevel -s
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=4
section_name='System configuration'
display_command='prtconf'
write_section_header
if command -v prtconf >/dev/null 2>&1; then
	prtconf
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=5
section_name='LPAR configuration'
display_command='lparstat -i'
write_section_header
if command -v lparstat >/dev/null 2>&1; then
	lparstat -i
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=6
section_name='Virtual memory statistics'
display_command='vmstat 2 6'
write_section_header
if command -v vmstat >/dev/null 2>&1; then
	vmstat 2 6
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=7
section_name='Memory usage summary'
display_command='svmon -G'
write_section_header
if command -v svmon >/dev/null 2>&1; then
	svmon -G
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=8
section_name='Paging spaces'
display_command='lsps -a'
write_section_header
if command -v lsps >/dev/null 2>&1; then
	lsps -a
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=9
section_name='Filesystem space'
display_command='df -g'
write_section_header
if command -v df >/dev/null 2>&1; then
	df -g
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=10
section_name='Filesystems'
display_command='lsfs'
write_section_header
if command -v lsfs >/dev/null 2>&1; then
	lsfs
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=11
section_name='Volume groups'
display_command='lsvg'
write_section_header
if command -v lsvg >/dev/null 2>&1; then
	lsvg
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=12
section_name='Physical volumes'
display_command='lspv'
write_section_header
if command -v lspv >/dev/null 2>&1; then
	lspv
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=13
section_name='Disk devices'
display_command='lsdev -Cc disk'
write_section_header
if command -v lsdev >/dev/null 2>&1; then
	lsdev -Cc disk
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=14
section_name='Adapter devices'
display_command='lsdev -Cc adapter'
write_section_header
if command -v lsdev >/dev/null 2>&1; then
	lsdev -Cc adapter
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=15
section_name='Device paths'
display_command='lspath'
write_section_header
if command -v lspath >/dev/null 2>&1; then
	lspath
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=16
section_name='Network routes'
display_command='netstat -rn'
write_section_header
if command -v netstat >/dev/null 2>&1; then
	netstat -rn
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=17
section_name='Network interfaces'
display_command='netstat -in'
write_section_header
if command -v netstat >/dev/null 2>&1; then
	netstat -in
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=18
section_name='Error report'
display_command='errpt'
write_section_header
if command -v errpt >/dev/null 2>&1; then
	errpt
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

section_number=19
section_name='SRC services'
display_command='lssrc -a'
write_section_header
if command -v lssrc >/dev/null 2>&1; then
	lssrc -a
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

classified_sections=$((successful_sections + failed_sections + unavailable_sections))
if [ "$total_sections" -ne 19 ] || [ "$classified_sections" -ne 19 ]; then
	overall_status='INCOMPLETE / UNASSESSED'
elif [ "$successful_sections" -eq 19 ] && [ "$failed_sections" -eq 0 ] && [ "$unavailable_sections" -eq 0 ]; then
	overall_status='COMPLETE'
else
	overall_status='INCOMPLETE / UNASSESSED'
fi

printf '\nTotal sections: %s\n' "$total_sections"
printf 'Successful sections: %s\n' "$successful_sections"
printf 'Failed sections: %s\n' "$failed_sections"
printf 'Unavailable sections: %s\n' "$unavailable_sections"
printf 'Classified sections: %s\n' "$classified_sections"
printf 'Overall collection status: %s\n' "$overall_status"

printf '%s\n' "$evidence_file" >&3
if [ "$overall_status" = 'COMPLETE' ]; then
	exit 0
fi
exit 1
