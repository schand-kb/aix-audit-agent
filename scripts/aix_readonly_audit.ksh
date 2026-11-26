#!/usr/bin/ksh

set +x

# Run only from an engineer-controlled trusted directory not writable by
# untrusted users. Do not run from /tmp or another shared writable directory.
# By default the collector creates one new timestamped evidence file here.
# With --stdout it creates no evidence file.

PATH=/usr/bin:/usr/sbin:/sbin
LC_ALL=C
export PATH LC_ALL
unset ENV BASH_ENV CDPATH LIBPATH LD_LIBRARY_PATH LD_PRELOAD

output_mode=file
privilege_mode=unprivileged
while [ "$#" -gt 0 ]; do
	case "$1" in
		--stdout)
			if [ "$output_mode" != file ]; then
				printf '%s\n' 'Duplicate --stdout option.' >&2
				exit 2
			fi
			output_mode=stdout
			;;
		--privileged-readonly)
			if [ "$privilege_mode" != unprivileged ]; then
				printf '%s\n' 'Duplicate --privileged-readonly option.' >&2
				exit 2
			fi
			privilege_mode=controlled-readonly
			;;
		*)
			printf '%s\n' 'Usage: aix_readonly_audit.ksh [--stdout] [--privileged-readonly]' >&2
			exit 2
			;;
	esac
	shift
done
readonly output_mode privilege_mode
if [ "$privilege_mode" = controlled-readonly ]; then
	observed_os=$(/usr/bin/uname -s </dev/null)
	if [ "$?" -ne 0 ] || [ "$observed_os" != AIX ]; then
		printf '%s\n' 'Privileged collection refused: operating system is not confirmed as AIX.' >&2
		exit 1
	fi
fi
sudo_path=''
if [ "$privilege_mode" = controlled-readonly ]; then
	if [ -x /usr/bin/sudo ]; then
		sudo_path=/usr/bin/sudo
	elif [ -x /opt/freeware/bin/sudo ]; then
		sudo_path=/opt/freeware/bin/sudo
	fi
fi
readonly sudo_path

umask 077
set -C

exec 3>&1
if [ "$output_mode" = file ]; then
	timestamp=$(date '+%Y%m%d_%H%M%S' </dev/null)
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
	if exec 4> "$evidence_file"; then
		:
	else
		printf '%s\n' "Unable to create evidence file: $evidence_file" >&2
		exit 1
	fi
else
	exec 4>&1
fi
exec 1>&4 2>&1

metadata_status=COMPLETE
collection_start_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ' </dev/null)
if [ "$?" -ne 0 ] || [ -z "$collection_start_utc" ]; then
	collection_start_utc=UNAVAILABLE
	metadata_status=INCOMPLETE
fi

total_sections=19
successful_sections=0
failed_sections=0
unavailable_sections=0

write_section_header() {
	section_timestamp=$(date '+%Y%m%d_%H%M%S' </dev/null)
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
printf '%s\n' 'Collector version: 1.5'
printf 'Collection start UTC: %s\n' "$collection_start_utc"
printf 'Evidence output mode: %s\n' "$output_mode"
printf 'Privilege mode: %s\n' "$privilege_mode"
printf '%s\n' 'Section output and command stderr are captured together as evidence.'
printf '%s\n' 'PERMISSION DENIED is not inferred; nonzero results are FAILED.'

section_number=1
section_name='System hostname'
display_command='hostname'
write_section_header
if [ -x /usr/bin/hostname ]; then
	observed_hostname=$(/usr/bin/hostname </dev/null)
	command_rc=$?
	printf 'Observed hostname: %s\n' "$observed_hostname"
	if [ "$command_rc" -eq 0 ] && [ -z "$observed_hostname" ]; then
		printf '%s\n' 'Observed hostname is empty; identity is unavailable.'
		metadata_status=INCOMPLETE
	fi
	record_executed_status
else
	record_unavailable_status
fi
if [ "$privilege_mode" = controlled-readonly ] && \
	{ [ "$section_status" != COLLECTED ] || [ "$observed_hostname" != db2test ]; }; then
	printf '%s\n' 'Privileged collection refused: observed hostname is not db2test.'
	exit 1
fi

section_number=2
section_name='Operating system and kernel'
display_command='uname -a'
write_section_header
if command -v uname >/dev/null 2>&1; then
	uname -a </dev/null
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
	oslevel -s </dev/null
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
	prtconf </dev/null
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
	lparstat -i </dev/null
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
	vmstat 2 6 </dev/null
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
	svmon -G </dev/null
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
	lsps -a </dev/null
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
	df -g </dev/null
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
	lsfs </dev/null
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
	lsvg </dev/null
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
	lspv </dev/null
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
	lsdev -Cc disk </dev/null
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
	lsdev -Cc adapter </dev/null
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
	lspath </dev/null
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
	netstat -rn </dev/null
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
	netstat -in </dev/null
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
	errpt </dev/null
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
	lssrc -a </dev/null
	command_rc=$?
	record_executed_status
else
	record_unavailable_status
fi

v1_classified_sections=$((successful_sections + failed_sections + unavailable_sections))
if [ "$total_sections" -ne 19 ] || [ "$v1_classified_sections" -ne 19 ]; then
	v1_status='INCOMPLETE / UNASSESSED'
elif [ "$successful_sections" -eq 19 ] && [ "$failed_sections" -eq 0 ] && [ "$unavailable_sections" -eq 0 ]; then
	v1_status='COMPLETE'
else
	v1_status='INCOMPLETE / UNASSESSED'
fi

printf '\nTotal sections: %s\n' "$total_sections"
printf 'Successful sections: %s\n' "$successful_sections"
printf 'Failed sections: %s\n' "$failed_sections"
printf 'Unavailable sections: %s\n' "$unavailable_sections"
printf 'Classified sections: %s\n' "$v1_classified_sections"
printf 'V1 collection status: %s\n' "$v1_status"

v11_total=0
v11_successful=0
v11_failed=0
v11_unavailable=0
v11_skipped=0
v11_not_applicable=0
v11_section_number=19
v11_vg_cap=64
v11_pv_cap=256
v11_disk_cap=256
v11_fc_cap=64
v11_lv_cap=256
queried_lv_count=0
lv_cap_recorded=0
active_vg_inventory_valid=0
active_vg_inventory_names='|'

write_v11_section_header() {
	v11_section_number=$((v11_section_number + 1))
	v11_total=$((v11_total + 1))
	printf '\nSection %s: %s\n' "$v11_section_number" "$v11_section_name"
	printf 'Display command or skipped operation: %s\n' "$v11_display_command"
	section_timestamp=$(date '+%Y%m%d_%H%M%S' </dev/null)
	timestamp_rc=$?
	if [ "$timestamp_rc" -ne 0 ] || [ -z "$section_timestamp" ]; then
		section_timestamp='UNAVAILABLE'
	fi
	printf 'Collection timestamp: %s\n' "$section_timestamp"
	printf '%s\n' 'Command output and stderr (captured together):'
}

record_v11_executed_status() {
	printf 'Command return code: %s\n' "$command_rc"
	if [ "$command_rc" -eq 0 ]; then
		v11_section_status='COLLECTED'
		v11_successful=$((v11_successful + 1))
	else
		v11_section_status='FAILED'
		v11_failed=$((v11_failed + 1))
	fi
	printf 'Section status: %s\n' "$v11_section_status"
}

record_v11_unavailable_status() {
	printf '%s\n' 'Command was not executed: unavailable on the fixed PATH.'
	v11_section_status='COMMAND NOT AVAILABLE'
	v11_unavailable=$((v11_unavailable + 1))
	printf 'Section status: %s\n' "$v11_section_status"
}

record_v11_skipped() {
	write_v11_section_header
	printf '%s\n' 'Command was not executed; candidate text is not repeated.'
	v11_section_status='SKIPPED'
	v11_skipped=$((v11_skipped + 1))
	printf 'Section status: %s\n' "$v11_section_status"
}

record_v11_not_applicable() {
	write_v11_section_header
	printf 'Validated physical volume: %s\n' "$candidate_name"
	printf 'Validated volume group: %s\n' "$pv_inventory_group"
	printf 'Reason: %s\n' "$v11_not_applicable_reason"
	v11_section_status='NOT APPLICABLE'
	v11_not_applicable=$((v11_not_applicable + 1))
	printf 'Section status: %s\n' "$v11_section_status"
}

valid_vg_name() {
	[ "${#candidate_name}" -ge 1 ] && [ "${#candidate_name}" -le 15 ] || return 1
	case "$candidate_name" in
		[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]*) ;;
		*) return 1 ;;
	esac
	case "$candidate_name" in
		*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*)
			return 1
			;;
	esac
	return 0
}

valid_disk_or_pv_name() {
	case "$candidate_name" in
		hdisk*)
			candidate_suffix=${candidate_name#hdisk}
			;;
		ultracs_hdisk*)
			candidate_suffix=${candidate_name#ultracs_hdisk}
			;;
		*)
			return 1
			;;
	esac
	case "$candidate_suffix" in
		''|*[!0123456789]*)
			return 1
			;;
	esac
	return 0
}

valid_fc_name() {
	case "$candidate_name" in
		fcs*)
			candidate_suffix=${candidate_name#fcs}
			;;
		*)
			return 1
			;;
	esac
	case "$candidate_suffix" in
		''|*[!0123456789]*)
			return 1
			;;
	esac
	return 0
}

is_safe_inventory_line() {
	line_to_check=$1
	tab_character=$(printf '\t')
	while [ -n "$line_to_check" ]; do
		line_character=${line_to_check%"${line_to_check#?}"}
		line_to_check=${line_to_check#?}
		case "$line_character" in
			"$tab_character") ;;
			[[:cntrl:]]) return 1 ;;
		esac
	done
	return 0
}

valid_pv_inventory_row() {
	[ "$#" -ge 3 ] && [ "$#" -le 4 ] || return 1
	case "$2" in
		????????????????) ;;
		[Nn][Oo][Nn][Ee]) ;;
		*) return 1 ;;
	esac
	case "$2" in
		*[!0123456789ABCDEFabcdef]*)
			case "$2" in
				[Nn][Oo][Nn][Ee]) ;;
				*) return 1 ;;
			esac
			;;
	esac
	case "$3" in
		[Nn][Oo][Nn][Ee]) ;;
		*)
			pv_row_vg=$3
			pv_row_device=$candidate_name
			candidate_name=$pv_row_vg
			if ! valid_vg_name; then
				candidate_name=$pv_row_device
				return 1
			fi
			candidate_name=$pv_row_device
			;;
	esac
	if [ "$#" -eq 4 ]; then
		[ "$4" = 'active' ] || return 1
		case "$3" in
			[Nn][Oo][Nn][Ee]) return 1 ;;
		esac
	fi
	return 0
}

valid_lsdev_inventory_row() {
	[ "$#" -ge 4 ] || return 1
	case "$2" in
		Available|Defined) ;;
		*) return 1 ;;
	esac
	case "$3" in
		''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]*)
			return 1
			;;
	esac
	shift 3
	inventory_description=$*
	case "$candidate_name" in
		hdisk*|ultracs_hdisk*)
			valid_disk_or_pv_name || return 1
			[ -n "$inventory_description" ]
			return $?
			;;
		fcs*)
			case "$inventory_description" in
				*[Ff]ibre*[Cc]hannel*|*' FC '*|FC\ *|*' FC') return 0 ;;
				*) return 1 ;;
			esac
			;;
		*)
			return 1
			;;
	esac
}

write_discovery_output_block() {
	block_remaining=$1
	block_line_number=0
	newline='
'
	printf '%s\n' 'DISCOVERY OUTPUT BEGIN'
	while [ -n "$block_remaining" ]; do
		case "$block_remaining" in
			*"$newline"*)
				block_line=${block_remaining%%"$newline"*}
				block_remaining=${block_remaining#*"$newline"}
				;;
			*)
				block_line=$block_remaining
				block_remaining=''
				;;
		esac
		block_line_number=$((block_line_number + 1))
		if is_safe_inventory_line "$block_line"; then
			printf '| %s\n' "$block_line"
		else
			printf '| [discovery line %s rejected: control character]\n' "$block_line_number"
		fi
	done
	printf '%s\n' 'DISCOVERY OUTPUT END'
	printf '%s\n' 'Discovery output is line-prefixed and safely normalized.'
}

process_lv_inventory() {
	lv_remaining=$1
	lv_header_seen=0
	lv_row_number=0
	lv_newline='
'
	while [ -n "$lv_remaining" ]; do
		case "$lv_remaining" in
			*"$lv_newline"*)
				lv_line=${lv_remaining%%"$lv_newline"*}
				lv_remaining=${lv_remaining#*"$lv_newline"}
				;;
			*)
				lv_line=$lv_remaining
				lv_remaining=''
				;;
		esac
		lv_row_number=$((lv_row_number + 1))
		if ! is_safe_inventory_line "$lv_line"; then
			v11_section_name="Unsafe logical volume row $lv_row_number"
			v11_display_command='No command executed; discovery line contained a control character'
			record_v11_skipped
			continue
		fi
		set -- $lv_line
		[ "$#" -gt 0 ] || continue
		if [ "$lv_header_seen" -eq 0 ]; then
			if [ "$#" -eq 1 ] && [ "$1" = "${validated_vg}:" ]; then
				continue
			fi
			if [ "$#" -eq 10 ] && [ "$1" = LV ] && [ "$2" = NAME ] && \
				[ "$3" = TYPE ] && [ "$4" = LPs ] && [ "$5" = PPs ] && \
				[ "$6" = PVs ] && [ "$7" = LV ] && [ "$8" = STATE ] && \
				[ "$9" = MOUNT ] && [ "${10}" = POINT ]; then
				lv_header_seen=1
				continue
			fi
			v11_section_name="Invalid logical volume header row $lv_row_number"
			v11_display_command='No command executed; logical volume inventory header was not recognized'
			record_v11_skipped
			return
		fi
		lv_name=$1
		lv_valid=1
		[ "${#lv_name}" -ge 1 ] && [ "${#lv_name}" -le 64 ] || lv_valid=0
		case "$lv_name" in
			[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]*) ;;
			*) lv_valid=0 ;;
		esac
		case "$lv_name" in
			*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*) lv_valid=0 ;;
		esac
		if [ "$#" -lt 7 ]; then
			lv_valid=0
		else
			case "$2" in ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*) lv_valid=0 ;; esac
			for lv_number in "$3" "$4" "$5"; do
				case "$lv_number" in ''|*[!0123456789]*) lv_valid=0 ;; esac
			done
			case "$6" in open/*|opened/*|closed/*|closed) ;; *) lv_valid=0 ;; esac
		fi
		if [ "$lv_valid" -ne 1 ]; then
			v11_section_name="Invalid logical volume row $lv_row_number"
			v11_display_command='No command executed; row failed the approved inventory structure'
			record_v11_skipped
		elif [ "$queried_lv_count" -ge "$v11_lv_cap" ]; then
			if [ "$lv_cap_recorded" -eq 0 ]; then
				v11_section_name='Logical volume enumeration cap reached'
				v11_display_command='Logical volumes beyond the cap were not queried'
				record_v11_skipped
				lv_cap_recorded=1
			fi
		else
			queried_lv_count=$((queried_lv_count + 1))
			v11_section_name='Logical volume detail'
			v11_display_command="lslv \"$lv_name\""
			write_v11_section_header
			if [ -x /usr/sbin/lslv ]; then
				/usr/sbin/lslv "$lv_name" </dev/null
				command_rc=$?
				record_v11_executed_status
			else
				record_v11_unavailable_status
			fi
		fi
	done
	if [ "$lv_header_seen" -ne 1 ]; then
		v11_section_name='Logical volume inventory header missing'
		v11_display_command='No logical volume detail commands executed'
		record_v11_skipped
	fi
}

collect_vg_details() {
	validated_vg=$1

	v11_section_name='Active volume group summary'
	v11_display_command="lsvg \"$validated_vg\""
	write_v11_section_header
	if command -v lsvg >/dev/null 2>&1; then
		lsvg "$validated_vg" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi

	v11_section_name='Active volume group physical volumes'
	v11_display_command="lsvg -p \"$validated_vg\""
	write_v11_section_header
	if command -v lsvg >/dev/null 2>&1; then
		lsvg -p "$validated_vg" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi

	v11_section_name='Active volume group logical volumes'
	v11_display_command="lsvg -l \"$validated_vg\""
	write_v11_section_header
	if command -v lsvg >/dev/null 2>&1; then
		lv_inventory_output=$(lsvg -l "$validated_vg" </dev/null 2>&4)
		command_rc=$?
		write_discovery_output_block "$lv_inventory_output"
		record_v11_executed_status
		if [ "$command_rc" -eq 0 ]; then
			process_lv_inventory "$lv_inventory_output"
		else
			v11_section_name='Logical volume detail discovery failed'
			v11_display_command='No logical volume detail commands executed'
			record_v11_skipped
		fi
	else
		record_v11_unavailable_status
		v11_section_name='Logical volume detail discovery unavailable'
		v11_display_command='No logical volume detail commands executed'
		record_v11_skipped
	fi
}

collect_pv_detail() {
	validated_pv=$1
	v11_section_name='Physical volume detail'
	v11_display_command="lspv \"$validated_pv\""
	write_v11_section_header
	if command -v lspv >/dev/null 2>&1; then
		lspv "$validated_pv" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi
}

collect_device_configuration() {
	validated_device=$1
	v11_section_name='Device configuration detail'
	v11_display_command="lscfg -vl \"$validated_device\""
	write_v11_section_header
	if command -v lscfg >/dev/null 2>&1; then
		lscfg -vl "$validated_device" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi
}

collect_fc_attributes() {
	validated_fcs=$1
	v11_section_name='Fibre Channel adapter attributes'
	v11_display_command="lsattr -El \"$validated_fcs\""
	write_v11_section_header
	if command -v lsattr >/dev/null 2>&1; then
		lsattr -El "$validated_fcs" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi
}

process_vg_inventory() {
	inventory_remaining=$1
	inventory_line_number=0
	valid_vg_count=0
	queried_vg_count=0
	cap_recorded=0
	active_vg_inventory_valid=1
	active_vg_inventory_names='|'
	newline='
'
	while [ -n "$inventory_remaining" ]; do
		case "$inventory_remaining" in
			*"$newline"*)
				inventory_line=${inventory_remaining%%"$newline"*}
				inventory_remaining=${inventory_remaining#*"$newline"}
				;;
			*)
				inventory_line=$inventory_remaining
				inventory_remaining=''
				;;
		esac
		inventory_line_number=$((inventory_line_number + 1))
		if ! is_safe_inventory_line "$inventory_line"; then
			active_vg_inventory_valid=0
			v11_section_name="Unsafe active volume group row $inventory_line_number"
			v11_display_command='No command executed; discovery line contained a control character'
			record_v11_skipped
			continue
		fi
		set -- $inventory_line
		if [ "$#" -gt 0 ]; then
			candidate_name=$1
			if [ "$#" -ne 1 ] || ! valid_vg_name; then
				active_vg_inventory_valid=0
				v11_section_name="Invalid volume group row $inventory_line_number"
				v11_display_command='No command executed; row did not contain exactly one valid VG name'
				record_v11_skipped
			else
				valid_vg_count=$((valid_vg_count + 1))
				active_vg_inventory_names="${active_vg_inventory_names}${candidate_name}|"
				if [ "$queried_vg_count" -lt "$v11_vg_cap" ]; then
					queried_vg_count=$((queried_vg_count + 1))
					collect_vg_details "$candidate_name"
				else
					if [ "$cap_recorded" -eq 0 ]; then
						v11_section_name='Volume group enumeration cap reached'
						v11_display_command='Active volume groups beyond the cap were not queried'
						record_v11_skipped
						cap_recorded=1
					fi
					v11_section_name="Volume group row $inventory_line_number skipped by cap"
					v11_display_command='No command executed'
					record_v11_skipped
				fi
			fi
		fi
	done
	if [ "$valid_vg_count" -eq 0 ]; then
		printf '%s\n' 'Enumeration result: no validated active volume group names were available.'
	fi
}

process_pv_inventory() {
	inventory_remaining=$1
	inventory_line_number=0
	valid_pv_count=0
	queried_pv_count=0
	cap_recorded=0
	newline='
'
	while [ -n "$inventory_remaining" ]; do
		case "$inventory_remaining" in
			*"$newline"*)
				inventory_line=${inventory_remaining%%"$newline"*}
				inventory_remaining=${inventory_remaining#*"$newline"}
				;;
			*)
				inventory_line=$inventory_remaining
				inventory_remaining=''
				;;
		esac
		inventory_line_number=$((inventory_line_number + 1))
		if ! is_safe_inventory_line "$inventory_line"; then
			v11_section_name="Unsafe physical volume row $inventory_line_number"
			v11_display_command='No command executed; discovery line contained a control character'
			record_v11_skipped
			continue
		fi
		set -- $inventory_line
		if [ "$#" -gt 0 ]; then
			candidate_name=$1
			pv_inventory_group=$3
			if ! valid_disk_or_pv_name || ! valid_pv_inventory_row "$@"; then
				v11_section_name="Invalid physical volume row $inventory_line_number"
				v11_display_command='No command executed; row failed the approved inventory structure'
				record_v11_skipped
			else
				valid_pv_count=$((valid_pv_count + 1))
				if [ "$queried_pv_count" -lt "$v11_pv_cap" ]; then
					queried_pv_count=$((queried_pv_count + 1))
					case "$pv_inventory_group" in
						[Nn][Oo][Nn][Ee])
							v11_section_name='Physical volume detail not applicable'
							v11_display_command='No command executed; detailed query not applicable for an unassigned PV'
							v11_not_applicable_reason='physical volume is not assigned to a volume group'
							record_v11_not_applicable
							;;
						*)
							if [ "$active_vg_inventory_valid" -ne 1 ]; then
								v11_section_name='Physical volume detail skipped'
								v11_display_command='No command executed; active volume group discovery is incomplete or unvalidated'
								record_v11_skipped
							else
								case "$active_vg_inventory_names" in
									*"|${pv_inventory_group}|"*)
										collect_pv_detail "$candidate_name"
										;;
									*)
										v11_section_name='Physical volume detail not applicable'
										v11_display_command='No command executed; detailed query not applicable for an inactive volume group'
										v11_not_applicable_reason='physical volume belongs to a volume group that is not active'
										record_v11_not_applicable
										;;
								esac
							fi
							;;
					esac
				else
					if [ "$cap_recorded" -eq 0 ]; then
						v11_section_name='Physical volume enumeration cap reached'
						v11_display_command='Physical volumes beyond the cap were not queried'
						record_v11_skipped
						cap_recorded=1
					fi
					v11_section_name="Physical volume row $inventory_line_number skipped by cap"
					v11_display_command='No command executed'
					record_v11_skipped
				fi
			fi
		fi
	done
	if [ "$valid_pv_count" -eq 0 ]; then
		printf '%s\n' 'Enumeration result: no valid physical volume names were returned.'
	fi
}

process_disk_inventory() {
	inventory_remaining=$1
	inventory_line_number=0
	valid_disk_count=0
	queried_disk_count=0
	cap_recorded=0
	newline='
'
	while [ -n "$inventory_remaining" ]; do
		case "$inventory_remaining" in
			*"$newline"*)
				inventory_line=${inventory_remaining%%"$newline"*}
				inventory_remaining=${inventory_remaining#*"$newline"}
				;;
			*)
				inventory_line=$inventory_remaining
				inventory_remaining=''
				;;
		esac
		inventory_line_number=$((inventory_line_number + 1))
		if ! is_safe_inventory_line "$inventory_line"; then
			v11_section_name="Unsafe disk row $inventory_line_number"
			v11_display_command='No command executed; discovery line contained a control character'
			record_v11_skipped
			continue
		fi
		set -- $inventory_line
		if [ "$#" -gt 0 ]; then
			candidate_name=$1
			if ! valid_disk_or_pv_name || ! valid_lsdev_inventory_row "$@"; then
				v11_section_name="Invalid disk row $inventory_line_number"
				v11_display_command='No command executed; row failed the approved inventory structure'
				record_v11_skipped
			else
				valid_disk_count=$((valid_disk_count + 1))
				if [ "$queried_disk_count" -lt "$v11_disk_cap" ]; then
					queried_disk_count=$((queried_disk_count + 1))
					collect_device_configuration "$candidate_name"
				else
					if [ "$cap_recorded" -eq 0 ]; then
						v11_section_name='Disk enumeration cap reached'
						v11_display_command='Disks beyond the cap were not queried'
						record_v11_skipped
						cap_recorded=1
					fi
					v11_section_name="Disk row $inventory_line_number skipped by cap"
					v11_display_command='No command executed'
					record_v11_skipped
				fi
			fi
		fi
	done
	if [ "$valid_disk_count" -eq 0 ]; then
		printf '%s\n' 'Enumeration result: no valid disk names were returned.'
	fi
}

process_fc_inventory() {
	inventory_remaining=$1
	inventory_line_number=0
	fc_candidate_count=0
	queried_fc_count=0
	cap_recorded=0
	newline='
'
	while [ -n "$inventory_remaining" ]; do
		case "$inventory_remaining" in
			*"$newline"*)
				inventory_line=${inventory_remaining%%"$newline"*}
				inventory_remaining=${inventory_remaining#*"$newline"}
				;;
			*)
				inventory_line=$inventory_remaining
				inventory_remaining=''
				;;
		esac
		inventory_line_number=$((inventory_line_number + 1))
		if ! is_safe_inventory_line "$inventory_line"; then
			v11_section_name="Unsafe adapter row $inventory_line_number"
			v11_display_command='No command executed; discovery line contained a control character'
			record_v11_skipped
			continue
		fi
		set -- $inventory_line
		if [ "$#" -gt 0 ]; then
			candidate_name=$1
			case "$candidate_name" in
				NAME|name) ;;
				fcs*)
					fc_candidate_count=$((fc_candidate_count + 1))
					if valid_fc_name && valid_lsdev_inventory_row "$@"; then
						if [ "$queried_fc_count" -lt "$v11_fc_cap" ]; then
							queried_fc_count=$((queried_fc_count + 1))
							collect_fc_attributes "$candidate_name"
							collect_device_configuration "$candidate_name"
						else
							if [ "$cap_recorded" -eq 0 ]; then
								v11_section_name='Fibre Channel adapter enumeration cap reached'
								v11_display_command='FC adapters beyond the cap were not queried'
								record_v11_skipped
								cap_recorded=1
							fi
							v11_section_name="Fibre Channel adapter row $inventory_line_number skipped by cap"
							v11_display_command='No command executed'
							record_v11_skipped
						fi
					else
						v11_section_name="Invalid Fibre Channel adapter row $inventory_line_number"
						v11_display_command='No command executed; row failed the approved inventory structure'
						record_v11_skipped
					fi
					;;
				*) ;;
			esac
		fi
	done
	if [ "$fc_candidate_count" -eq 0 ]; then
		printf '%s\n' 'Enumeration result: no Fibre Channel adapter candidates were returned.'
	fi
}

run_v11_inventory() {
	v11_section_name=$1
	v11_display_command=$2
	inventory_kind=$3

	write_v11_section_header
	printf '%s\n' 'Command stderr (captured as produced):'
	case "$inventory_kind" in
		vg)
			if command -v lsvg >/dev/null 2>&1; then
				inventory_output=$(lsvg -o </dev/null 2>&4)
				command_rc=$?
			else
				record_v11_unavailable_status
				printf '%s\n' 'Enumeration not attempted because the discovery command is unavailable.'
				return
			fi
			;;
		pv)
			if command -v lspv >/dev/null 2>&1; then
				inventory_output=$(lspv </dev/null 2>&4)
				command_rc=$?
			else
				record_v11_unavailable_status
				printf '%s\n' 'Enumeration not attempted because the discovery command is unavailable.'
				return
			fi
			;;
		disk)
			if command -v lsdev >/dev/null 2>&1; then
				inventory_output=$(lsdev -Cc disk </dev/null 2>&4)
				command_rc=$?
			else
				record_v11_unavailable_status
				printf '%s\n' 'Enumeration not attempted because the discovery command is unavailable.'
				return
			fi
			;;
		fc)
			if command -v lsdev >/dev/null 2>&1; then
				inventory_output=$(lsdev -Cc adapter </dev/null 2>&4)
				command_rc=$?
			else
				record_v11_unavailable_status
				printf '%s\n' 'Enumeration not attempted because the discovery command is unavailable.'
				return
			fi
			;;
	esac
	write_discovery_output_block "$inventory_output"
	record_v11_executed_status
	if [ "$command_rc" -ne 0 ]; then
		printf '%s\n' 'Enumeration not attempted because the discovery command failed.'
		return
	fi
	case "$inventory_kind" in
		vg) process_vg_inventory "$inventory_output" ;;
		pv) process_pv_inventory "$inventory_output" ;;
		disk) process_disk_inventory "$inventory_output" ;;
		fc) process_fc_inventory "$inventory_output" ;;
	esac
}

set -f
tab_character=$(printf '\t')
IFS=" $tab_character"
unset tab_character

v11_section_name='Active volume groups'
v11_display_command='lsvg -o'
run_v11_inventory "$v11_section_name" "$v11_display_command" vg

v11_section_name='Currently mounted filesystems'
v11_display_command='mount'
write_v11_section_header
if command -v mount >/dev/null 2>&1; then
	mount </dev/null
	command_rc=$?
	record_v11_executed_status
else
	record_v11_unavailable_status
fi

v11_section_name='Filesystem inode usage'
v11_display_command='df -i'
write_v11_section_header
if command -v df >/dev/null 2>&1; then
	df -i </dev/null
	command_rc=$?
	record_v11_executed_status
else
	record_v11_unavailable_status
fi

run_v11_inventory 'Physical volume discovery snapshot' 'lspv' pv
run_v11_inventory 'Disk discovery snapshot' 'lsdev -Cc disk' disk
run_v11_inventory 'Adapter discovery snapshot' 'lsdev -Cc adapter' fc

run_fixed_section() {
	v11_section_name=$1
	v11_display_command=$2
	shift 2
	write_v11_section_header
	if command -v "$1" >/dev/null 2>&1; then
		"$@" </dev/null
		command_rc=$?
		record_v11_executed_status
	else
		record_v11_unavailable_status
	fi
}

run_catalogue_section() {
	if [ "$#" -ne 1 ]; then
		printf '%s\n' 'Invalid catalogue dispatcher request.'
		return 1
	fi
	catalogue_id=$1
	case "$catalogue_id" in
		AIX-BOOT-001)
			v11_section_name='Boot device'
			set -- /usr/sbin/bootinfo -b
			;;
		AIX-BOOT-003)
			v11_section_name='Normal boot list'
			set -- /usr/bin/bootlist -m normal -o
			;;
		AIX-DUMP-001)
			v11_section_name='System dump configuration'
			set -- /usr/bin/sysdumpdev -l
			;;
		AIX-SW-002)
			v11_section_name='Interim fixes'
			set -- /usr/sbin/emgr -l
			;;
		AIX-TUNE-002)
			v11_section_name='Memory tunables'
			set -- /usr/sbin/vmo -a
			;;
		AIX-TUNE-003)
			v11_section_name='I/O tunables'
			set -- /usr/sbin/ioo -a
			;;
		AIX-TUNE-004)
			v11_section_name='Scheduler tunables'
			set -- /usr/sbin/schedo -a
			;;
		AIX-OPS-002)
			v11_section_name='Error logging configuration'
			set -- /usr/lib/errdemon -l
			;;
		*)
			printf '%s\n' 'Unknown catalogue dispatcher ID; no command executed.'
			return 1
			;;
	esac
	v11_display_command=$*
	write_v11_section_header
	printf 'Catalogue ID: %s\n' "$catalogue_id"
	printf 'Execution mode: %s\n' "$privilege_mode"
	if [ "$privilege_mode" = controlled-readonly ]; then
		if [ -z "$sudo_path" ]; then
			printf '%s\n' 'Command was not executed: fixed sudo executable unavailable.'
			v11_unavailable=$((v11_unavailable + 1))
			printf '%s\n' 'Section status: COMMAND NOT AVAILABLE'
			return 1
		fi
		printf 'Sudo executable: %s\n' "$sudo_path"
		if [ "$catalogue_id" = AIX-BOOT-003 ]; then
			bootlist_output=$("$sudo_path" -n "$@" </dev/null 2>&4)
			command_rc=$?
			printf '%s\n' "$bootlist_output"
		else
			"$sudo_path" -n "$@" </dev/null
			command_rc=$?
		fi
	elif [ -x "$1" ]; then
		if [ "$catalogue_id" = AIX-BOOT-003 ]; then
			bootlist_output=$("$@" </dev/null 2>&4)
			command_rc=$?
			printf '%s\n' "$bootlist_output"
		else
			"$@" </dev/null
			command_rc=$?
		fi
	else
		record_v11_unavailable_status
		return 0
	fi
	if [ "$catalogue_id" = AIX-BOOT-003 ] && [ "$command_rc" -eq 0 ] && [ -z "$bootlist_output" ]; then
		printf 'Command return code: %s\n' "$command_rc"
		printf '%s\n' 'Empty boot list output is inconclusive.'
		v11_failed=$((v11_failed + 1))
		printf '%s\n' 'Section status: FAILED'
	else
		record_v11_executed_status
	fi
	if [ "$privilege_mode" = controlled-readonly ] && [ "$command_rc" -ne 0 ]; then
		printf '%s\n' 'Privileged collection stopped after sudo command failure.'
		return 1
	fi
}

has_ntp_peer_row() {
	peer_remaining=$1
	newline='
'
	while [ -n "$peer_remaining" ]; do
		case "$peer_remaining" in
			*"$newline"*)
				peer_line=${peer_remaining%%"$newline"*}
				peer_remaining=${peer_remaining#*"$newline"}
				;;
			*)
				peer_line=$peer_remaining
				peer_remaining=''
				;;
		esac
		set -- $peer_line
		[ "$#" -ge 10 ] || continue
		case "$3" in ''|*[!0123456789]*) continue ;; esac
		case "$6" in ''|*[!0123456789]*) continue ;; esac
		case "$7" in ''|*[!01234567]*) continue ;; esac
		return 0
	done
	return 1
}

run_fixed_section 'LPAR identity' 'uname -L' uname -L
run_catalogue_section AIX-BOOT-001 || exit 1
run_fixed_section 'Last system boot' 'who -b' who -b
run_fixed_section 'DNS resolver configuration' 'cat /etc/resolv.conf' cat /etc/resolv.conf
run_fixed_section 'NTP service status' 'lssrc -s xntpd' lssrc -s xntpd
v11_section_name='NTP peer status'
v11_display_command='ntpq -pn'
write_v11_section_header
if command -v ntpq >/dev/null 2>&1; then
	ntp_output=$(ntpq -pn </dev/null 2>&4)
	command_rc=$?
	printf '%s\n' "$ntp_output"
	if [ "$command_rc" -eq 0 ] && ! has_ntp_peer_row "$ntp_output"; then
		printf 'Command return code: %s\n' "$command_rc"
		printf '%s\n' 'No usable NTP peer row was found.'
		v11_failed=$((v11_failed + 1))
		printf '%s\n' 'Section status: FAILED'
	else
		record_v11_executed_status
	fi
else
	record_v11_unavailable_status
fi
run_catalogue_section AIX-DUMP-001 || exit 1
run_fixed_section 'Installed software' 'lslpp -L' lslpp -L
run_catalogue_section AIX-SW-002 || exit 1
run_fixed_section 'Processor attributes' '/usr/sbin/lsattr -El proc0' /usr/sbin/lsattr -El proc0
run_fixed_section 'System attributes' '/usr/sbin/lsattr -El sys0' /usr/sbin/lsattr -El sys0
run_fixed_section 'Interface configuration' '/usr/sbin/ifconfig -a' /usr/sbin/ifconfig -a
run_catalogue_section AIX-BOOT-003 || exit 1
run_fixed_section 'Network tunables' '/usr/sbin/no -a' /usr/sbin/no -a
run_fixed_section 'NFS tunables' '/usr/sbin/nfso -a' /usr/sbin/nfso -a
run_fixed_section 'Detailed path state' "/usr/sbin/lspath -F 'path_id status parent connection'" \
	/usr/sbin/lspath -F 'path_id status parent connection'
run_catalogue_section AIX-TUNE-002 || exit 1
run_catalogue_section AIX-TUNE-003 || exit 1
run_catalogue_section AIX-TUNE-004 || exit 1
run_catalogue_section AIX-OPS-002 || exit 1

printf '%s\n' 'Known gap: lsmpio-only path details are not collected; lspath and lscfg are not equivalent.'
printf '%s\n' 'Known gap: application, backup, monitoring and DR assertions require approved external evidence.'

collection_end_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ' </dev/null)
if [ "$?" -ne 0 ] || [ -z "$collection_end_utc" ]; then
	collection_end_utc=UNAVAILABLE
	metadata_status=INCOMPLETE
fi

v11_classified_sections=$((v11_successful + v11_failed + v11_unavailable + v11_skipped + v11_not_applicable))
if [ "$v11_total" -ne "$v11_classified_sections" ]; then
	v11_status='INCOMPLETE / UNASSESSED'
elif [ "$v11_failed" -eq 0 ] && [ "$v11_unavailable" -eq 0 ] && [ "$v11_skipped" -eq 0 ]; then
	v11_status='COMPLETE'
else
	v11_status='INCOMPLETE / UNASSESSED'
fi

if [ "$v1_status" = 'COMPLETE' ] && [ "$v11_status" = 'COMPLETE' ] && [ "$metadata_status" = 'COMPLETE' ]; then
	overall_status='COMPLETE'
else
	overall_status='INCOMPLETE / UNASSESSED'
fi

printf '\nV1.5 extended total sections: %s\n' "$v11_total"
printf 'V1.5 extended successful sections: %s\n' "$v11_successful"
printf 'V1.5 extended failed sections: %s\n' "$v11_failed"
printf 'V1.5 extended unavailable sections: %s\n' "$v11_unavailable"
printf 'V1.5 extended skipped sections: %s\n' "$v11_skipped"
printf 'V1.5 extended not applicable sections: %s\n' "$v11_not_applicable"
printf 'V1.5 extended classified sections: %s\n' "$v11_classified_sections"
printf 'V1.5 extended counter invariant: %s = %s + %s + %s + %s + %s\n' \
	"$v11_total" "$v11_successful" "$v11_failed" "$v11_unavailable" "$v11_skipped" "$v11_not_applicable"
printf 'V1 collection status: %s\n' "$v1_status"
printf 'V1.5 extended collection status: %s\n' "$v11_status"
printf 'UTC metadata status: %s\n' "$metadata_status"
printf 'Collection end UTC: %s\n' "$collection_end_utc"
printf 'Overall collection status: %s\n' "$overall_status"

if [ "$output_mode" = file ]; then
	printf '%s\n' "$evidence_file" >&3
fi
if [ "$overall_status" = 'COMPLETE' ]; then
	exit 0
fi
exit 1
