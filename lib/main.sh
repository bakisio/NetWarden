#!/bin/bash
################################################################################
#              _   _      ___          __           _                          #
#             | \ | |    | \ \        / /          | |                         #
#             |  \| | ___| |\ \  /\  / /_ _ _ __ __| | ___ _ __                #
#             | . ` |/ _ \ __\ \/  \/ / _` | '__/ _` |/ _ \ '_ \               #
#             | |\  |  __/ |_ \  /\  / (_| | | | (_| |  __/ | | |              #
#             |_| \_|\___|\__| \/  \/ \__,_|_|  \__,_|\___|_| |_|              #
#                                                                              #
################################################################################
#                                                                              #
# NetWarden v1 main library                                                    #
# By: Doug Ingham (doug@bakis.io)                                              #
#                                                                              #
################################################################################

#######################################
#           Global Functions          #
#######################################

logPrefix="NetWarden"
log(){
	echo "[$(date '+%x %X')] $logPrefix $*" >> $logfile
}
export -f log

# Queuing function using a sleep lock to keep the process queue at $maxQueue (default 1).
# Currently using LIFO to prioritise child-processes.
# Note: If the server is overloaded by other processes, the lock will never be released.
checkQueue(){
	# Clean dead PIDs from the queue
	for pid in $(ls $lockDir); do
		if ! ps ${pid:-1} >/dev/null 2>&1; then rm $lockDir/$pid 2>/dev/null; fi
	done

	# Add PID to the queue
	touch "$lockFile" || exit 1										# Add PID to the queue or die to prevent runaways
	cpus=$(grep -cw ^processor /proc/cpuinfo)						# Count CPUs
	load=$(cut -f1 -d'.' /proc/loadavg)								# Calculate load (rounded)
	memFree=$(grep MemAvailable /proc/meminfo | awk '{print $2}')	# Calculate available memory

	while true; do
		until (( $load/$cpus < $maxQueue )) && (( $memFree > $memReserve )); do
			sleep 2
			load=$(cut -f1 -d'.' /proc/loadavg)
			memFree=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
		done

		minPID=$(ls $lockDir | sort -n | tail -n1)
		if [[ $$ = ${minPID:-$$} ]]; then
			rm $lockFile
			return 0
		else
			# Add an extra wait to allow the new process to spin up
			sleep 5
		fi
	done
}
export -f checkQueue

isValidIP() {
	if [[ ! "$1" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
		return 1
	fi
}
export -f isValidIP

isValidSubnet() {
	if [[ ! "$1" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/(0|[12][0-9]|3[0-2])$ ]]; then
		return 1
	fi
}
export -f isValidSubnet

#######################################
#       Initialise Environment        #
#######################################

# Log directory
if [[ ! -d "$(dirname $logfile)" ]]; then
	if ! mkdir -p "$(dirname $logfile)"; then
		log "ERROR: Unable to write to log directory ($cachedir)"
		exit 1;
	fi
else
	if ! echo >> $logfile; then
		log "ERROR: Unable to write to log directory ($cachedir)"
		exit 1;
	fi
fi

# Cache directory
if [[ ! -d "$cachedir" ]]; then
	if ! mkdir -p $cachedir; then
		log "ERROR: Unable to create cache directory ($cachedir)"
		exit 1
	fi
elif [[ ! -w "$cachedir" ]]; then
		log "ERROR: Unable to write to cache directory ($cachedir)"
		exit 1
fi

# Lock directory
lockDir="${cachedir}/queue"; lockFile="${lockDir}/$$"
if [[ ! -d "$lockDir" ]]; then
	if ! mkdir -p $lockDir; then
		log "ERROR: Unable to create lock directory ($lockDir)"
		exit 1
	fi
elif [[ ! -w "$lockDir" ]]; then
		log "ERROR: Unable to write to lock directory ($lockDir)"
		exit 1
fi

if [[ "$dbengine" = "sqlite3" ]]; then
	source ./lib/sqlite.db
fi

