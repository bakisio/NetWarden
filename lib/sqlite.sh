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
# NetWarden v1 SQLite 3 library                                                #
# By: Doug Ingham (doug@bakis.io)                                              #
#                                                                              #
################################################################################
#!/bin/bash

#######################################
#             Environment             #
#######################################

dbfile="${cachedir}/${db}.db"

# Check write permissions
if [[ -e "$dbfile" ]] && [[ ! -w "$dbfile" ]]; then
	echo "Erro: Sem permissões de escrita no $dbfile"
	exit 1
# Initialise database
elif [[ ! -f "$dbfile" ]]; then
	$sql 'CREATE TABLE hosts (
		ip TEXT NOT NULL,
		mac TEXT,
		hostname TEXT,
		vendor TEXT,
		os TEXT,
		first_seen INT,
		last_seen INT,
		PRIMARY KEY (ip)
	);'
	$sql 'CREATE TABLE vulns (
		ip TEXT NOT NULL,
		service TEXT,
		port INT,
		defcred INT,
		defcred_t INT,
		weakcred INT,
		weakcred_t INT,
		highvulns INT,
		highvulns_t INT,
		critvulns INT,
		critvulns_t INT
	);'
	# vulns: defcred, weakcred, highvulns, critvulns
	$sql 'CREATE TABLE services (
		ip TEXT NOT NULL,
		service TEXT,
		port INT,
		product TEXT,
		version TEXT,
		first_seen INT,
		last_seen INT
	);'
		#PRIMARY KEY (ip)
		#FOREIGN KEY (ip) REFERENCES hosts (ip)
		#	ON DELETE CASCADE ON UPDATE CASCADE
fi

#######################################
#              Functions              #
#######################################

# Single-select
sql(){
	# Concurrency hack
	false; until [[ $? = 0 ]]; do
		sqlite3 $dbfile $@
	done
}
export -f sql
