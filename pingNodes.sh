#!/bin/bash

# Small Script to check the ping round trip times RTT to other Stakepools or to incoming Peers
#
# ATADA Stakepool - Contact Telegram @atada_stakepool
#
# HOW TO USE:
#       - First, make sure you have the little helper tool 'tcptraceroute' installed. if not, the script will be
#	  angry and tells you that. this tool is needed to make a "ping" request to the open tcp port if the normal
#	  ping command fails.
#	- Set the correct Listenport of your choosen node
#	- Set the direction (OUT = conns to other stakepools, IN = conns into your node from other peers)
#	- Set the maxpeers to test only xxx ips, this will only count reachable ips. If you have for example 400 incoming connections, you
#	  can limit the shown peers to 100 for example.
#	- Set your netstat-wording, depends on your install, normally ESTABLISHED
#	- At the end you get a summary also with a list of the Topx peers, set the parameter SHOWTOP to 0 for showing ALL
#	- If you wanna share a screencapture to the community but you want to hide all the IPs, set the parameter HIDEIP to YES
#	- Enable/Disable the GeoLocation lookup for all the peers in the summary
#
#	You're done, just call the script:  ./pingNodes.sh
#
#	Sometimes you're not allowed to read out netstat with PIDs, try running the script like: sudo ./pingNodes.sh
#
#	You can also set the parameters for the LISTENPORT and DIRECTION via the commandline:
#       ./pingNodes.sh <LISTENPORT>     		example: ./pingNodes.sh 3000
#	./pingNodes.sh <LISTENPORT> <DIRECTION>		example: ./pingNodes.sh 3000 OUT
#
# Best regards, Martin (@atada_stakepool telegram)
#


### Listenport
LISTENPORT="3001"	#Listen Port of your running node, same as in stakepool-config listen_address, NOT REST api port!

### Direction
DIRECTION="OUT"		#Show connections going out to other Stakepools, default OUT
#DIRECTION="IN"		#Show connectinos coming into your Stakepool-Node from other peers

### MaxPeers
MAXPEERS="0"		#Test ALL peers, default 0
#MAXPEERS="50"		#Test only 50 peers

### Netstat-Established wording
NETSTATEST="ESTABLISHED"	#English Version, default ESTABLISHED
#NETSTATEST="VERBUNDEN"         #German Version

### Show Top x peers in the summary
SHOWTOP=40		#Show the Top40 peers in the summary, default 40
#SHOWTOP=0		#Show ALL peers in the summary

### Hide IPs in the summary to share a screenshot
HIDEIP="NO"		#Show the IPs, default
#HIDEIP="YES"		#Hide the IPs

### Show peer GeoLocation in summary. Uses GeoService via https://json.geoiplookup.io/, NOT FOR COMMERCIAL USE, USE IT ONLY FOR PRIVATE TESTING !
#SHOWGEOINFO="NO"	#Don't lookup the Geo information
SHOWGEOINFO="YES"	#Lookup each IP in the summary for Geo information(slow), default


########################################################################################################
# Don't edit below this line
########################################################################################################

VERSION="1.4"

exists()
{
  command -v "$1" >/dev/null 2>&1
}

#Check if tcptraceroute is installed
if ! exists tcptraceroute; then
  echo -e "\nPlease install the little tool 'tcptraceroute' !\n"
  echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install tcptraceroute\e[0m\n"
  echo -e "Thx! :-)\n"
  exit 2
fi

#Check parameters from cli -> overwrite script parameters
if [[ ! $1 == "" ]]; then LISTENPORT=$1; fi	#Set listenport from cli (parameter 1)
if [[ ! $2 == "" ]]; then DIRECTION=$2; fi     #Set listenport from cli (parameter 2)

#Check Direction
if [[ ${DIRECTION^^} == "OUT" ]]; then DIRECTION="OUT"; else DIRECTION="IN"; fi

#Check HideIP
if [[ ${HIDEIP^^} == "NO" ]]; then HIDEIP="NO"; else HIDEIP="YES"; fi

#Check ShowGeoInfo
if [[ ${SHOWGEOINFO^^} == "NO" ]]; then SHOWGEOINFO="NO"; 
  else SHOWGEOINFO="YES";

	#Check if curl and jq is installed
	if ! exists curl; then
	  echo -e "\nTo use the SHOWGEOINFO feature, you need the tool 'curl' !\n"
	  echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install curl\e[0m\n"
	  echo -e "Thx! :-)\n"
	  exit 2
	fi
        if ! exists jq; then
          echo -e "\nTo use the SHOWGEOINFO feature, you need the tool 'jq' !\n"
          echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install jq\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
        fi
   fi

#Check Maxpeers
if [[ ${MAXPEERS} == 0 ]]; then MAXPEERS=-1; fi

#Get node process PID
netstatListen=$(netstat -lnp 2> /dev/null |& grep -e ":${LISTENPORT}" |& awk {'print $7'} |& tail -n 1)

if [[ ${netstatListen} == "" ]]; then
echo
printf "\npingNodes (Ver ${VERSION}) - ERROR\n\n"
printf "\e[0mThere is no node process listening on Port\e[97m %s\e[0m!\n" ${LISTENPORT}
printf "\e[0mMaybe the listenport number is wrong, or no node running?\n\n"
exit 2
fi

pid=$(echo ${netstatListen} | cut -d"/" -f1)
#JORMNAME=$(echo ${netstatListen} | cut -d"/" -f2)
#JORMNAME=$(ps -p ${pid} | tail -n 1 | awk {'print $4'})
JORMNAME=$(ps -p ${pid} -o comm=)

if [[ ${pid} == "" || ${pid} == "-" ]]; then
echo
printf "\npingNodes (Ver ${VERSION}) - ERROR\n\n"
printf "\e[0mThere is a node process listening on Port\e[97m %s\e[0m,\nbut you don't have the rights to read out the PID!\n" ${LISTENPORT}
printf "\e[0mYou can try to run the script as root with sudo like:\n\e[97msudo ./pingNodes.sh\e[0m\n\n"
exit 2
fi


#Get NetworkStats depending on choosen direction
if [[ ${DIRECTION} == "OUT" ]]; then 
netstatPeers=$(netstat -np 2> /dev/null |& grep -e "${NETSTATEST}.* ${pid}/" |& grep -v ":${LISTENPORT}" |& awk {'print $5'})
else
netstatPeers=$(netstat -np 2> /dev/null |& grep -e "${NETSTATEST}.* ${pid}/" |& grep ":${LISTENPORT}" |& awk {'print $5'})
fi

#Sort list to get only uniq IP:Port combinations
netstat_sorted=$(printf '%s\n' "${netstatPeers[@]}" |& sort )

uniqPeers=()

#Add all unique IP:Port to the array and count it
let peerCNTABS=0; 
for PEER in $netstat_sorted; do
peerIP=$(echo ${PEER} | cut -d: -f1); peerPORT=$(echo ${PEER} | cut -d: -f2)
if [[ ! "$peerIP" == "$lastpeerIP" ]]; then	#Only filter for unique IPs in this version
	lastpeerIP=$peerIP; lastpeerPORT=$peerPORT;
	uniqPeers+=("${peerIP}:${peerPORT} ")
	let peerCNTABS++;
fi
done
lastpeerIP=""; lastpeerPORT=""

#Build new NetstatPeers, now only unique
netstatPeers=$(printf '%s\n' "${uniqPeers[@]}")

#Set all Variables to zero
let peerCNT=0; let peerRTTSUM=0; let peerCNT0=0; let peerCNT1=0; let peerCNT2=0; let peerCNT3=0; let peerCNT4=0
let bestRTT=0; let worstRTT=0; let pct1=0; let pct2=0; let pct3=0; let pct4=0;
rtt_results=()

#Print Header
echo
printf "\n pingNodes (Ver ${VERSION}) - Get some data\n\n"

echo -e " --------------------+------------------------------------------------------------------"
printf "             \e[0mProcess | \e[97m%s(%s) \e[0mlistening on Port\e[97m %d\e[0m\n" ${JORMNAME} ${pid} ${LISTENPORT}
if [[ ${DIRECTION} == "OUT" ]]; then
printf "           \e[0mDirection | Found \e[97m%d\e[0m unique IPs going \e[97mOUT\e[0m to other Node(s)\n" ${peerCNTABS}
else
printf "           \e[0mDirection | Found \e[97m%d\e[0m unique IPs coming \e[97mIN\e[0m to your Node from Peers\n" ${peerCNTABS} 
fi
if [[ ${MAXPEERS} -gt 0 ]]; then
printf "             \e[0m   Show | \e[97m%s\e[0m reachable Peers\n" ${MAXPEERS}
else
printf "             \e[0m   Show | \e[97mALL\e[0m reachable Peers\n"
fi
echo -e " --------------------+------------------------------------------------------------------"
echo


#Ping every Node in the list
for PEER in $netstatPeers; do

peerIP=$(echo ${PEER} | cut -d: -f1)
peerPORT=$(echo ${PEER} | cut -d: -f2)

#Ping peerIP
checkPEER=$(ping -c 2 -i 0.3 -w 1 ${peerIP} 2>&1)
if [[ $? == 0 ]]; then #Ping OK, show RTT
        peerRTT=$(echo ${checkPEER} | tail -n 1 | cut -d/ -f5 | cut -d. -f1)
	pingTYPE="icmp"
	let peerCNT++
	let "peerRTTSUM = $peerRTTSUM + $peerRTT"
	else #Normal ping is not working, try tcptraceroute to the given port
	checkPEER=$(tcptraceroute -n -S -f 255 -m 255 -q 1 -w 1 ${peerIP} ${peerPORT} 2>&1 | tail -n 1)
	if [[ ${checkPEER} == *'[open]'* ]]; then
	        peerRTT=$(echo ${checkPEER} | awk {'print $4'} | cut -d. -f1)
		pingTYPE="tcp/syn"
		let peerCNT++
                let "peerRTTSUM = $peerRTTSUM + $peerRTT" 
		else #Nope, no response
	        peerRTT=-1
		pingTYPE=""
	fi
fi

if [[ $peerCNT -gt 0 ]]; then let "peerRTTAVG = $peerRTTSUM / $peerCNT"; fi

#Save best and worst peer
if [[ $peerCNT == 1 && $worstRTT == 0 && $bestRTT == 0 ]]; then worstIP=${peerIP}; worstPORT=${peerPORT}; worstRTT=$peerRTT; bestIP=${peerIP}; bestPORT=${peerPORT}; bestRTT=$peerRTT; fi
if [[ $peerRTT -gt $worstRTT ]]; then worstIP=${peerIP}; worstPORT=${peerPORT}; worstRTT=$peerRTT; fi
if [[ $peerRTT -gt -1 && $peerRTT -lt $bestRTT ]]; then bestIP=${peerIP}; bestPORT=${peerPORT}; bestRTT=$peerRTT; fi

#Set colors and count entries
if [[ $peerRTT -gt 199 ]]; then  COLOR="\e[35m"; let peerCNT4++; 
elif [[ $peerRTT -gt 99 ]]; then  COLOR="\e[91m"; let peerCNT3++;
elif [[ $peerRTT -gt 49 ]]; then  COLOR="\e[33m"; let peerCNT2++;
elif [[ $peerRTT -gt -1 ]]; then  COLOR="\e[32m"; let peerCNT1++;
else COLOR="\e[0m"; let peerCNT0++; peerRTT="---"
fi

printf "\e[97m%3d/%3d\e[90m # ${COLOR}IP: %15s\tPORT:%5s\tRTT: %3s ms\t\e[97mAVG: %3s ms\e[90m\t%7s\e[0m\n" ${peerCNT} ${peerCNTABS} ${peerIP} ${peerPORT} ${peerRTT} ${peerRTTAVG} ${pingTYPE}

if [[ ! "$peerRTT" == "---" ]]; then rtt_results+=("${peerRTT}:${peerIP}:${peerPORT} "); fi

#Check if MaxPeers reached, if yes, exit loop
if [[ $peerCNT == $MAXPEERS ]]; then break; fi

done


#Print Summary

let "peerCNTSKIPPED = $peerCNTABS - $peerCNT - $peerCNT0"  
echo -e "\n\n pingNodes (Ver ${VERSION}) - RTT Summary \n"

printf  "             \e[0mProcess | \e[97m%s(%s)\e[0m listening on Port\e[97m %d\e[0m\n" ${JORMNAME} ${pid} ${LISTENPORT}

if [[ ${DIRECTION} == "OUT" ]]; then
printf  "           \e[0mDirection | Found \e[97m%d\e[0m unique IPs going \e[97mOUT\e[0m to other Node(s)\n" ${peerCNTABS}
else
printf  "           \e[0mDirection | Found \e[97m%d\e[0m unique IPs coming \e[97mIN\e[0m to your Node from Peers\n" ${peerCNTABS}
fi
if [[ ${MAXPEERS} -gt 0 ]]; then
printf  "           \e[0m     Show | \e[97m%s\e[0m reachable Peers\n" ${MAXPEERS}
else
printf  "           \e[0m     Show | \e[97mALL\e[0m reachable Peers\n"
fi

#Generate Bars
barline=" ██████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████"

let "peerCNTREACHED = $peerCNT1 + $peerCNT2 + $peerCNT3 + $peerCNT4"
let peerMAX=0
if [[ $peerCNTREACHED -gt 0 ]]; then
 if [[ $peerCNT1 -gt $peerMAX ]]; then let peerMAX=$peerCNT1; fi
 if [[ $peerCNT2 -gt $peerMAX ]]; then let peerMAX=$peerCNT2; fi
 if [[ $peerCNT3 -gt $peerMAX ]]; then let peerMAX=$peerCNT3; fi
 if [[ $peerCNT4 -gt $peerMAX ]]; then let peerMAX=$peerCNT4; fi

bar1=${barline:0:((1 + ($peerCNT1 * 50 / $peerMAX)))}; let "pct1 = $peerCNT1 * 10000 / $peerCNTREACHED";
bar2=${barline:0:((1 + ($peerCNT2 * 50 / $peerMAX)))}; let "pct2 = $peerCNT2 * 10000 / $peerCNTREACHED";
bar3=${barline:0:((1 + ($peerCNT3 * 50 / $peerMAX)))}; let "pct3 = $peerCNT3 * 10000 / $peerCNTREACHED";
bar4=${barline:0:((1 + ($peerCNT4 * 50 / $peerMAX)))}; let "pct4 = $peerCNT4 * 10000 / $peerCNTREACHED";
fi

echo -e " --------------------+------------------------------------------------------------------"
printf  "     0ms to 50ms RTT | \e[32m%4d  %s %3.1f%%\e[0m\n" ${peerCNT1} " ${bar1}" ${pct1}e-2
printf  "   50ms to 100ms RTT | \e[33m%4d  %s %3.1f%%\e[0m\n" ${peerCNT2} " ${bar2}" ${pct2}e-2
printf  "  100ms to 200ms RTT | \e[91m%4d  %s %3.1f%%\e[0m\n" ${peerCNT3} " ${bar3}" ${pct3}e-2
printf  " more than 200ms RTT | \e[35m%4d  %s %3.1f%%\e[0m\n" ${peerCNT4} " ${bar4}" ${pct4}e-2
printf  "         unreachable | \e[0m%4d\e[0m\n" ${peerCNT0}
printf  "             skipped | \e[0m%4d\e[0m\n" ${peerCNTSKIPPED}
echo -e " --------------------+------------------------------------------------------------------"
printf  "               total | \e[97m%4d established\e[0m\n" ${peerCNTABS}
printf  "   total average RTT | \e[97m%4d ms\e[0m\n" ${peerRTTAVG}

#Hide IPs?
if [[ $HIDEIP == "YES" ]]; then bestIP="x.x.x.x"; worstIP="x.x.x.x"; fi

#Color for best peer and show it
if [[ $bestRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $bestRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $bestRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $bestRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi
printf  "           best Peer | ${COLOR}%s on Port %s with %s ms RTT\e[0m\n" ${bestIP} ${bestPORT} ${bestRTT}

#Color for worst peer and show it
if [[ $worstRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $worstRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $worstRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $worstRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi
printf  "          worst Peer | ${COLOR}%s on Port %s with %s ms RTT\e[0m\n" ${worstIP} ${worstPORT} ${worstRTT}
echo -e " --------------------+------------------------------------------------------------------\n"

#Only show Top-x peers if some peers were reached
if [[ $peerCNTREACHED -gt 0 ]]; then

if [[ $SHOWGEOINFO == "YES" ]]; then
				printf "\e[97m  %4s %15s%7s   %5s    %20s   %s\e[0m\n\n" 'Top-X' 'IP     ' 'PORT' 'RTT' 'Country(CC)' 'City/Region'
				else
				printf "\e[97m\t%4s\t%15s\t%8s\t%5s\e[0m\n\n" 'Top-X' 'IP     ' 'PORT' 'RTT'
fi


let peerCNT=0;

rtt_sorted=$(printf '%s\n' "${rtt_results[@]}" | sort -n)

for PEER in $rtt_sorted; do

peerRTT=$(echo ${PEER} | cut -d: -f1)
peerIP=$(echo ${PEER} | cut -d: -f2)
peerPORT=$(echo ${PEER} | cut -d: -f3)

let peerCNT++;

if [[ $peerRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $peerRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $peerRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $peerRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi

#Do the Geo look up if enabled
if [[ $SHOWGEOINFO == "YES" ]]; then
	peerGEOJSON=$(curl -s https://json.geoiplookup.io/${peerIP})
	peerGEO_SUCCESS=$(echo ${peerGEOJSON} | jq -r .success)
	if [[ ${peerGEO_SUCCESS} == "true" ]]; then
		peerGEO_COUNTRYCODE=$(echo ${peerGEOJSON} | jq -r .country_code)
		peerGEO_COUNTRYNAME=$(echo ${peerGEOJSON} | jq -r .country_name)
		peerGEO_COUNTRY=$(echo "${peerGEO_COUNTRYNAME}(${peerGEO_COUNTRYCODE})")
		peerGEO_CITY=$(echo ${peerGEOJSON} | jq -r .city)
		peerGEO_REGION=$(echo ${peerGEOJSON} | jq -r .region)
		peerGEO_CITYREGION=$(echo "${peerGEO_CITY}/${peerGEO_REGION}")
        else
		peerGEO_COUNTRY=""
		peerGEO_CITYREGION=""
        fi
fi

#Hide the IP if enabled
if [[ $HIDEIP == "YES" ]]; then peerIP="x.x.x.x"; fi

if [[ $SHOWGEOINFO == "YES" ]]; then
				printf "\e[97m %4s${COLOR}   %15s%7s %5s ms   %20s   %s\e[0m\n" ${peerCNT} ${peerIP} ${peerPORT} ${peerRTT} ${peerLOCATION} "${peerGEO_COUNTRY}" "${peerGEO_CITYREGION}"
				else
				printf "\e[97m\t%4s\t${COLOR}%15s\t%8s\t%3s ms\e[0m\n" ${peerCNT} ${peerIP} ${peerPORT} ${peerRTT}
fi

if [[ $peerCNT == $SHOWTOP ]]; then break; fi

done
fi

echo

