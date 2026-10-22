# lib/components/firewall.sh, firewalld services and ports
#
# Everything goes into the zone of the interface with the default route, or firewalld's default zone without one
# Each change is made twice, with and without --permanent, instead of --reload, as firewall-cmd(1) describes
#
# On firewalld 2.3.2 even the runtime queryService and queryPort ask for a password on every call
# Source is PK_ACTION_CONFIG_INFO on both in firewall/server/firewalld.py, which polkit makes auth_admin_keep
#
# So queries only run as root, which polkit lets through
# A plain check without root at hand reports that it cannot tell

want::firewall_service() {
	task::requirement "Allow ${1} through the firewall" sudo firewall::_allowed firewall::_allow --service "$1"
}

want::firewall_port() {
	task::requirement "Allow ${1} through the firewall" sudo firewall::_allowed firewall::_allow --port "$1"
}

firewall::zone() {
	local interface zone
	interface="$(ip -4 route show default | grep -oP 'dev \K\S+' | head -1)"
	zone="$(firewall-cmd --get-zone-of-interface="${interface}" 2>/dev/null)"
	[[ -n "${zone}" && "${zone}" != "no zone" ]] || zone="$(firewall-cmd --get-default-zone)" || return 1
	printf '%s\n' "${zone}"
}

firewall::_allowed() {
	local kind="$1" item="$2" zone
	systemctl is-active --quiet firewalld || return 1
	[[ "${TASK_MODE}" == apply ]] || core::root_without_asking || return "${CORE_EXIT_UNKNOWN}"
	zone="$(firewall::zone)" || return 1
	core::as_root firewall-cmd --zone="${zone}" "--query-${kind#--}=${item}" >/dev/null 2>&1 || return 1
	core::as_root firewall-cmd --permanent --zone="${zone}" "--query-${kind#--}=${item}" >/dev/null 2>&1
}

firewall::_allow() {
	local kind="$1" item="$2" zone
	zone="$(firewall::zone)" || return 1
	core::as_root firewall-cmd --permanent --zone="${zone}" "--add-${kind#--}=${item}" >/dev/null || return 1
	core::as_root firewall-cmd --zone="${zone}" "--add-${kind#--}=${item}" >/dev/null
}
