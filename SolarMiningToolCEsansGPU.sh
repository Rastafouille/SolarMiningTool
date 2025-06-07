#!/usr/bin/env bash

Repertoire_Script=$(cd $( dirname ${BASH_SOURCE[0]}) && pwd )

##### PARAMETRES A REGLER
api_file_name="$Repertoire_Script/ApiData.json"
solax_tokenid=$(cat $api_file_name | jq '.solax_tokenid' | tr -d '"')
solax_sn=$(cat $api_file_name | jq '.solax_sn' | tr -d '"')

refresh_time_second=600

# Activer/désactiver le mode force la nuit
force_nuit_enable=1

log_file_name="$Repertoire_Script/log.txt"
cumul_file_name="$Repertoire_Script/cumul.txt"

if [ ! -f "$log_file_name" ]; then
  > "$log_file_name"
fi

# Initialisation cumul du jour
aujourd_hui=$(date "+%Y-%m-%d")

if [ -f "$cumul_file_name" ]; then
  read last_date last_cumul <<< $(cat "$cumul_file_name" | tr ';' ' ')
  if [ "$last_date" == "$aujourd_hui" ]; then
    CE_cumul=$last_cumul
  else
    CE_cumul=0
  fi
else
  CE_cumul=0
fi

###### config chauffe-eau (CE)
CE_IP=192.168.1.68
CE_consigne=0
CE_puissance=0
CE_force=0

# Color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
CYAN='\033[1;36m'
NC='\033[0m'

# Fonction appel API SolaX v2
function get_solax_info() {
  local retries=5

  for ((i=1; i<=retries; i++)); do
    data=$(curl -s -X POST https://global.solaxcloud.com/api/v2/dataAccess/realtimeInfo/get \
      -H "Content-Type: application/json" \
      -H "tokenId: $solax_tokenid" \
      -d "{\"wifiSn\":\"$solax_sn\"}")

    success=$(echo $data | jq '.success')

    if [[ "$success" == "true" ]]; then
      acpower=$(echo $data | jq '.result.acpower')
      feedinpower=$(echo $data | jq '.result.feedinpower')

      if [[ "$acpower" == "null" ]]; then acpower=0; fi
      if [[ "$feedinpower" == "null" ]]; then feedinpower=0; fi

      echo "Production panneaux : $acpower W"
      echo "Surplus Production solaire : $feedinpower W"
      sleep 0.2
      return
    else
      code=$(echo $data | jq '.code')
      exception=$(echo $data | jq '.exception' | tr -d '"')
      echo -e "${RED}Erreur API Solax: code=$code message=$exception${NC}"

      if [[ "$code" == "104" ]]; then
        echo "Quota minute atteint. Attente avant retry..."
        sleep 65
      else
        break
      fi
    fi
  done

  echo -e "${RED}Impossible d'obtenir les données Solax après $retries tentatives.${NC}"
  acpower=0
  feedinpower=0
}

# Lecture puissance chauffe-eau
function CE_get() {
  CE_puissance=$(curl -s "$CE_IP/update")
  echo "Puissance chauffe eau = $CE_puissance W"
}

# Envoi consigne chauffe-eau
function CE_set() {
  curl -s "$CE_IP/set?consigne=$1" > /dev/null
  echo "Consigne puissance chauffe eau = $1 W"
}

# Boucle principale
while :; do
  clear

  echo -e "${BLUE}"
  figlet -f standard "Solar Heating Control"
  echo -e "${YELLOW}================================================================${NC}"
  echo -e "${BLUE}By https://github.com/Rastafouille ${NC}"
  echo -e "${BLUE}$(date)${NC}"
  echo

  echo -e "${YELLOW}Période de rafraîchissement : $refresh_time_second s ${NC}"
  echo

  echo -e "${CYAN}***   Importation data solaire   ***${NC}"
  get_solax_info

  echo -e "${CYAN}***   Importation puissance chauffe-eau   ***${NC}"
  CE_get

  heure=$(date '+%H')

  if ((force_nuit_enable == 1)); then
    if ((heure == 1 && CE_cumul < 4500)); then
      CE_consigne=0
      echo "MODE force (1h)"
      CE_force=1
    elif ((heure == 2 && CE_cumul < 3000)); then
      CE_consigne=0
      echo "MODE force (2h)"
      CE_force=1
    elif ((heure == 3 && CE_cumul < 1500)); then
      CE_consigne=0
      echo "MODE force (3h)"
      CE_force=1
    elif ((heure == 4)); then
      CE_cumul=0
    else
      CE_consigne=$((${CE_puissance%.*} + $feedinpower))
      echo "MODE solaire"
      CE_force=0
    fi
  else
    if ((heure == 4)); then
      CE_cumul=0
    fi

    CE_consigne=$((${CE_puissance%.*} + $feedinpower))
    echo "MODE solaire (force désactivé)"
    CE_force=0
  fi

  if ((CE_consigne > 0)); then
    CE_set "$CE_consigne"
    if ((CE_force == 0)); then
      CE_cumul=$((CE_cumul + CE_consigne * refresh_time_second / 3600))
    fi
  else
    CE_consigne=0
    CE_set "$CE_consigne"
  fi

  echo "Cumul puissance sur la journée = $CE_cumul W/h"

  # Sauvegarde cumul + date
  echo "$aujourd_hui;$CE_cumul" > "$cumul_file_name"

  # LOG
  ligne="$(date), Surplus=$feedinpower, Consigne CE=$CE_consigne, Réel CE=$CE_puissance, Cumul CE=$CE_cumul"
  sed -i "1i$ligne" $log_file_name

  sleep $refresh_time_second
done
