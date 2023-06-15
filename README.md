```
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
# Por: Doug Ingham                                                             #
# Ver: 1.7.2 (07/06/23)                                                        #
#                                                                              #
################################################################################
#                                 NetWarden                                    #
# I'm watching you!                                                            #
#                                                                              #
# TODO:                                                                        #
# - Implement proper DB (MySQL/MariaDB)                                        #
# - [Zbx] Implement two groups, managed & unmanaged                            #
# - [Zbx] Add templates to hosts with existing templates                       #
#                                                                              #
################################################################################

#######################################
#               Manual                #
#######################################

NetWarden v1.7.2 (07/06/23)
Usage: netwarden <action> <type> <target>

DISCOVER:
    discover devices <file|ip[/network]>         - Scan for new devices using ping

SCAN:
    scan ports <ip[/network]> <ports>            - Scan target for specific open port(s) using formats: 22 21,22,23 21-23
    scan ports <ip[/network]> <all|common>       - Scan target for all, or only common, open ports
    scan users <default> <ip[/network]> [service] [port] [file]
                                                 - Test target for default credentials
    scan vulns <ip[/network]>                    - Scan target for known vulnerabilities
    scan new devices [hours]                     - Run default vulnerability scans for all devices discovered x hours ago
    scan new [vuln] [hours]                      - Run default vulnerability scans for all devices discovered x hours ago

GET:
    get host services <ip>                       - List services identified on host

CLEAN:
    clean [hosts|services|all] [days]            - Remove objects not seen in the last X days

SYNC:
    sync [ip]                                    - Syncronise connected services

MISC:
    help                                         - Print help
```
