#!/bin/bash
####################################################
#                                                  #
# Tribunal de Justica do Estado de Mato Grosso     #
# Departamento de Conectividade                    #
#                                                  #
# Por: Doug Ingham                                 #
# Ver: 0.7.1 (08/05/23)                            #
#                                                  #
####################################################
#          NetWarden Zabbix 5.4 API                #
#                                                  #
# https://www.zabbix.com/documentation/5.4/en/manual/api
# https://blog.zabbix.com/zabbix-api-scripting-via-curl-and-jq/12434/
# https://jsonpathfinder.com/                      #
# https://www.zabbix.com/documentation/current/en/manpages/zabbix_sender
#                                                  #
####################################################

#######################################
#               Manual                #
#######################################

print_help(){ echo '
NetWarden Zabbix API (v0.7.1 08/05/23)
Usage: zabbix.sh <action> <type> <target>

GET:
	get hostid
	get hostname
	get itemid
	get groupid
	get templateid

ADD:
	add host
	add item

UPDATE:
	update host
	update item

MISC:
	help									- Print help

'; exit
}


#######################################
#             Environment             #
#######################################

source netwarden.conf

logPrefix="Zabbix"
url="${zabbixUrl}/api_jsonrpc.php"
server="${zabbixHost}"
user="${zabbixUser}"
password="${zabbixPass}"
group="${zabbixGroup}"
template="${zabbixTemplate}"
key_hostname="netwarden.hostname"
key_mac="netwarden.mac"
key_vendor="netwarden.vendor"
key_os="netwarden.os"
key_firstseen="netwarden.firstseen"
key_lastseen="netwarden.lastseen"
key_defcred="netwarden.defcred" #netwarden.defcred[ssh,22]
key_weakcred="netwarden.weakcred"
key_critvuln="netwarden.critvuln"
key_highvuln="netwarden.highvuln"
key_discovery_svc="netwarden.svc.discovery"
key_product="netwarden.product"
key_version="netwarden.version"

# Safely set variables from command-line ("eval is evil!")
AllowedVars=(ip hostname mac vendor os port service lastseen item value)
args=("$@") # Transform into array
for ((i=0;i<${#args[@]};i++)); do
	arg="${args[$i]}"
	# Arguments containing '=' are arguments (as opposed to actions, eg. get)
	if [[ "$arg" =~ = ]]; then
		var="$(echo $arg | cut -f1 -d'=')"
		val="$(echo $arg | cut -f2 -d'=')"

		# Check that each argument is permitted via the AllowedVars array
		for ((v=0;v<${#AllowedVars[@]};v++)); do
			if [[ "$var" = "${AllowedVars[$v]}" ]]; then
				# Set the arguments as local variables
				eval "$var"='$val'
			fi
		done

	fi
done

# Fazer uma limpeza antes de encerrar o script
function cleanup {
	if [[ -n $auth ]]; then logout; fi
}
trap cleanup EXIT

#######################################
#              Functions              #
#######################################


isValidIP(){
	if [[ ! "$ip" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
		return 1
	fi
}

validate_key(){
	# Use indirect expansion to associate item with key_ vars
	key="key_$item"
	if [[ -z ${!key} ]]; then
		echo "Error: Item ${item} doesn't have a valid key."
		exit 1
	else
		eval key="${!key}"
	fi
}

login(){
	auth=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
	\"method\": \"user.login\",
	\"params\": {
	\"user\": \"$user\",
	\"password\": \"$password\"
	},
	\"id\": 1,
	\"auth\": null
	}
	" $url | \
	jq -r '.result'
	)
	if [[ -z $auth ]]; then return 1; fi
}

logout(){
	curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
		\"jsonrpc\": \"2.0\",
		\"method\": \"user.logout\",
		\"params\": [],
		\"id\": 1,
		\"auth\": \"$auth\"
	}
	" $url >/dev/null
}

get_hostid(){
	hostid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"host.get\",
		\"params\": {
			\"output\": [\"hostid\"],
			\"filter\": {
				\"ip\": \"${1:-$ip}\"
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].hostid' | tr -d '\n'
	)
	if [[ -z $hostid ]] || [[ "$hostid" = "null" ]]; then
		unset hostid
		return 1
	fi
}

get_hostname(){
	hostname=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"host.get\",
		\"params\": {
			\"output\": [\"host\"],
			\"filter\": {
				\"ip\": \"${1:-$ip}\"
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].host' | tr -d '\n'
	)
	if [[ -z $hostname ]] || [[ "$hostname" = "null" ]]; then
		unset hostname
		return 1
	fi
}

get_groupid(){
	groupid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"hostgroup.get\",
		\"params\": {
			\"output\": [\"groupid\"],
			\"filter\": {
				\"name\": \"$group\"
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].groupid' | tr -d '\n'
	)

	if [[ -z $groupid ]] || [[ "$groupid" = "null" ]]; then
		add_group
	fi
}

get_templateid(){
	templateid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"template.get\",
		\"params\": {
			\"output\": [\"templateid\"],
			\"filter\": {
				\"host\": \"$template\"
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].templateid' | tr -d '\n'
	)
	if [[ -z $templateid ]] || [[ "$templateid" = "null" ]]; then
		unset templateid
		return 1
	fi
}

get_itemid(){
	if [[ -z $hostid ]]; then
		get_hostid || return 1
	fi

	itemid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"item.get\",
		\"params\": {
			\"output\": [\"itemid\"],
			\"hostids\": \"$hostid\",
			\"filter\": {
				\"key_\": \"$key\"
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].itemid' | tr -d '\n'
	)
	if [[ -z $itemid ]] || [[ "$itemid" = "null" ]]; then
		unset itemid
		return 1
	fi
}

add_group(){
	groupid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"hostgroup.create\",
		\"params\": {
			\"name\": \"$group\"
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].groupids' | tr -d '\n'
	)
	if [[ -z $groupid ]] || [[ "$groupid" = "null" ]]; then
		log "ERROR: Unable to add group $group"
		return 1
	else
		log "INFO: Added group $group"
	fi
}

add_host(){
	if ! get_groupid || ! get_templateid; then
		return 1
	fi

	hostid=$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"host.create\",
		\"params\": {
			\"groups\": [
				{
					\"groupid\": \"$groupid\"
				}
			],
			\"host\": \"${hostname:-$ip}\",
			\"interfaces\": [
				{
					\"type\": 1,
					\"main\": 1,
					\"useip\": 1,
					\"ip\": \"$ip\",
					\"dns\": \"\",
					\"port\": \"10050\"
				}
			],
			\"templates\": [
				{
					\"templateid\": \"$templateid\"
				}
			]
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result.hostids[0]' | tr -d '\n'
	)

	if [[ -z $hostid ]] || [[ "$hostid" = "null" ]]; then
		log "ERROR: Unable to add host ${hostname:-$ip}"
		return 1
	else
		log "INFO: Added host ${hostname:-$ip}"
	fi

	#until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_firstseen" --value "$lastseen") =~ "failed: 0" ]]; do sleep 5; done

	#until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_lastseen" --value "$lastseen") =~ "failed: 0" ]]; do sleep 5; done
	#until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_hostname" --value "${hostname:-$ip}") =~ "failed: 0" ]]; do sleep 5; done
	#until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_mac" --value "$mac") =~ "failed: 0" ]]; do sleep 5; done
	#until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_vendor" --value "$vendor") =~ "failed: 0" ]]; do sleep 5; done
	sleep 5
	#update_host
}

send_discovery_items(){
	local value="[ "
	while IFS= read -r line; do
		local service="$(echo $line | cut -f1 -d'|')"
		local port="$(echo $line | cut -f2 -d'|')"

		local value+="{ \"{#SERVICE}\":\"${service}\", \"{#PORT}\":\"${port}\" },"

	done < <(./netwarden get host services $ip)
	local value="$(echo $value | sed 's/,$/ ]/')"

	#if get_hostname && isManagedHost; then #Redundant
	if get_hostname; then
		until [[ $(zabbix_sender --zabbix-server "$server" --host "$hostname" --key "$key_discovery_svc" --value "$value") =~ "failed: 0" ]]; do sleep 5; done
	fi
}

# Check if host is managed (part of NetWarden $group)
# return 1 = host isn't managed
isManagedHost(){
	if [[ -z $hostid ]]; then
		get_hostid || exit 1
	fi

	if [[ "${group}" = "$(curl -k -s -X POST \
	-H 'Content-Type: application/json-rpc' \
	-d " \
	{
	\"jsonrpc\": \"2.0\",
		\"method\": \"host.get\",
		\"params\": {
			\"output\": [\"hostid\"],
			\"selectGroups\": \"extend\",
			\"filter\": {
				\"hostid\": [
					\"$hostid\"
				]
			}
		},
		\"auth\": \"$auth\",
		\"id\": 1
	}
	" $url | \
	jq -r '.result[0].groups[].name' |\
	grep "^${group}$"
	)" ]]; then
		return 0
	else
		return 1
	fi
}

update_host(){
	#get_templateid &&

	if isManagedHost; then
		curl -k -s -X POST \
		-H 'Content-Type: application/json-rpc' \
		-d " \
		{
		\"jsonrpc\": \"2.0\",
			\"method\": \"host.update\",
			\"params\": {
				\"hostid\": \"$hostid\",
				\"host\": \"${hostname:-$ip}\"
				\"name\": \"${hostname:-$ip}\"
			},
			\"auth\": \"$auth\",
			\"id\": 1
		}
		" $url > /dev/null
		
		if [[ -n $hostname ]]; then
			until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_hostname" --value "${hostname:-$ip}") ]]; do sleep 5; done
		fi
		if [[ -n $mac ]]; then
			until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_mac" --value "$mac") ]]; do sleep 5; done
		fi
		if [[ -n $lastseen ]]; then
			until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_lastseen" --value "$lastseen") ]]; do sleep 5; done
		fi
		if [[ -n $vendor ]]; then
			until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_vendor" --value "$vendor") ]]; do sleep 5; done
		fi
		if [[ -n $os ]]; then
			until [[ $(zabbix_sender --zabbix-server "$server" --host "${hostname:-$ip}" --key "$key_os" --value "$os") ]]; do sleep 5; done
		fi
		log "INFO: Updated host ${hostname:-$ip} $mac $vendor $os"
	fi
	#TODO: if host managed, just add $template
}

update_item(){
	if [[ -n "$service" ]]; then
		send_discovery_items
		if [[ -n $lastseen ]]; then
			key_lastseen="$key_lastseen[${service},${port}]"
		fi
		if [[ -n $key ]]; then
			key="${key}[${service},${port}]"
		fi
	else
		get_hostname
	fi

	if [[ -n $lastseen ]]; then
		until [[ $(zabbix_sender --zabbix-server "$server" --host "$hostname" --key "$key_lastseen" --value "$lastseen") =~ "failed: 0" ]]; do sleep 5; done
	fi
	if [[ -n $key ]]; then
		until [[ $(zabbix_sender --zabbix-server "$server" --host "$hostname" --key "$key" --value "$value") =~ "failed: 0" ]]; do sleep 5; done
		log "INFO: Updated item $key on host $hostname"
	fi
}

delete_item(){
	# Removing the item from the database & running a new discovery will mark the item for deletion
	if [[ -n "$service" ]]; then
		send_discovery_items
	fi
}



#######################################
#              Execution              #
#######################################


if [[ -n $item ]]; then
	validate_key
fi

if [[ -n $ip ]] && ! isValidIP; then
	echo "Error: Invalid IP ($ip)"
	exit 1
fi

if ! login; then
	echo "Auth failed!"
	exit 1
fi

case $1 in
	get)
		case $2 in
			hostid)
				get_hostid
				echo -n $hostid
			;;
			hostname)
				get_hostname
				echo -n $hostname
			;;
			itemid)
				get_itemid
				echo -n $itemid
			;;
			groupid)
				get_groupid
				echo -n $groupid
			;;
			templateid)
				get_templateid
				echo -n $templateid
			;;
		esac
	;;
	add)
		case $2 in
			host)
				add_host
				echo -n $hostid
			;;
		esac
	;;
	update)
		case $2 in
			host)
				get_hostid || add_host
				#if isManagedHost; then
					update_host
				#fi
			;;
			item)
				get_hostid || add_host
				if isManagedHost; then
					update_item
				fi
			;;
			discovery)
				case $3 in
					items)
						send_discovery_items
					;;
				esac
			;;
		esac
	;;
	*|help)
		print_help
	;;
esac
