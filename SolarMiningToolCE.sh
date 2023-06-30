#!/bin/bash

Repertoire_Script=$(cd $( dirname ${BASH_SOURCE[0]}) && pwd )

##### PARAMETRES A REGLER

api_file_name="$Repertoire_Script/ApiData.json" #fichier a modifier avec ses paramètres
    # import du json
    solax_tokenid=$(cat $api_file_name | jq '.solax_tokenid'| tr -d '"')
    solax_sn=$(cat $api_file_name | jq '.solax_sn'| tr -d '"')
    base64=$(cat $api_file_name | jq '.base64'| tr -d '"')

refresh_time_second=300

### Paramètres puissance, à régler

gpu_nombre=4

bleu_HC_max=250
bleu_HC_min=170
bleu_HC_worker_off_enable=0 # permettre l'arret sur worker en dessous de la valeur min, pas encore implémenter
bleu_HP_max=250
bleu_HP_min=170
bleu_HP_worker_off_enable=0

blanc_HC_max=250
blanc_HC_min=170
blanc_HC_worker_off_enable=0
blanc_HP_max=250
blanc_HP_min=170
blanc_HP_worker_off_enable=0

rouge_HC_max=250
rouge_HC_min=170
rouge_HC_worker_off_enable=0
rouge_HP_max=250
rouge_HP_min=170
rouge_HC_worker_off_enable=1

#### Autres paramètres - ne pas toucher 

log_file_name="$Repertoire_Script/solar_mining_log.txt"


echo $log_file_name

if [ -f /$log_file_name ]
  then
    true
  else
    >$log_file_name
fi

###### config chauffe-eau (CE)
CE_IP=192.168.1.48
CE_consigne=0
CE_puissance=0

#color codes

RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

### definition des fonctions #########################################################

function set_powerlimit() {
  echo -e "${ARROW} ${CYAN}***   Running Power limit setting   ***${NC}"
        nvidia-smi -pl $1
  sleep 0.2
}


# A MODIFIER EN FONCTION DE L'ONDULEUR, ici Solax

function get_solax_info() {
  data=$(curl -s "https://www.solaxcloud.com/proxyApp/proxy/api/getRealtimeInfo.do?tokenId=$solax_tokenid&sn=$solax_sn" 2>&1)
  #cat $data_file_name | jq '.'
  
 	acpower=$(echo $data | jq '.result.acpower')
	echo "Production panneaux : $acpower W"
  
	feedinpower=$(echo $data | jq '.result.feedinpower')
	echo "Surplus Production solaire : $feedinpower W"
  
  sleep 0.2
}


function get_tempo_color() {
    auth=$(curl -s -H "Authorization: Basic $base64" -H "Content-Type: application/x-www-form-urlencoded" -X POST https://digital.iservices.rte-france.com/token/oauth/ 2<&1)
  access_token=$(echo $auth | jq '.access_token' | tr -d '"')
  #echo "access token : "$access_token
  

  heure=$(expr $(date '+%H') + 0)

  if (($heure>5 & $heure<22))
    then tarif=HP
    else tarif=HC
  fi
  
  if (($heure<6))
  then
    start_date=$(date -d "-1day" '+%FT00:00:00')"%2B02:00"
    #echo $start_date
    end_date=$(date '+%FT01:00:00')"%2B02:00"
    #echo $end_date
  else
    start_date=$(date '+%FT00:00:00')"%2B02:00"
    #echo $start_date
    end_date=$(date -d "+1day" '+%FT01:00:00')"%2B02:00"
    #echo $end_date
  fi

  tempo_resp=$(curl -s -H "Authorization: Bearer $access_token"  -H "Accept: application/json" "https://digital.iservices.rte-france.com/open_api/tempo_like_supply_contract/v1/tempo_like_calendars?start_date=$start_date&end_date=$end_date" 2>&1)

  #tempo_color=$(cat $tempo_file | yq -p xml '.Tempo.Couleur'| tr -d '"') 
  
  #cat $tempo_file | jq '.' 
  tempo_color=$(echo $tempo_resp | jq '.tempo_like_calendars.values[0].value'| tr -d '"') 
  
  echo "Couleur Tempo du jour : "$tempo_color
  echo "Tarif EDF en cours : "$tarif
  echo

  sleep 0.2
}

function set_min_max_power() {

 case "$tempo_color" in
   BLUE)  
    case "$tarif" in
      HC)
        gpu_power_max=$bleu_HC_max
        gpu_power_min=$bleu_HC_min
      ;;
      HP)
        gpu_power_max=$bleu_HP_max
        gpu_power_min=$bleu_HP_min 
      ;;
    esac
   ;; 
   WHITE)  
     case "$tarif" in
      HC)
        gpu_power_max=$blanc_HC_max
        gpu_power_min=$blanc_HC_min
      ;;
      HP)
        gpu_power_max=$blanc_HP_max
        gpu_power_min=$blanc_HP_min 
      ;;
    esac 
   ;; 
   RED)  
     case "$tarif" in
      HC)
        gpu_power_max=$rouge_HC_max
        gpu_power_min=$rouge_HC_min
      ;;
      HP)
        gpu_power_max=$rouge_HP_max
        gpu_power_min=$rouge_HP_min 
      ;;
    esac
   ;;
 esac
 
echo "GPU power max : $gpu_power_max W"
echo "GPU power min : $gpu_power_min W"
echo

}

function CE_set(){
 curl -s "$CE_IP/set?consigne=$1"
 echo "Consigne puissance chauffe eau = $1 W"
}

function CE_get(){
 CE_puissance=$(curl -s "$CE_IP/update")
 echo "Puissance chauffe eau = $CE_puissance W"

}


### Boucle principale ####################################################

while :
do
  clear


  echo -e "${BLUE}"
  figlet -f standard "Solar Mining Tool"
  echo -e "${YELLOW}================================================================${NC}"
  echo -e "${BLUE}By https://github.com/Rastafouille ${NC}"
  echo -e "${BLUE}$(date)${NC}"
  echo    

  echo -e "${GREEN}Nombre de GPU : $gpu_nombre ${NC}"
  echo -e "${GREEN}Periode rafraichissement : $refresh_time_second s ${NC}"
  echo
  
#  echo -e "${ARROW} ${CYAN}***   GPUs infos   ***${NC}"
#  echo
#  nvidia-smi
#  echo
  
  
  echo -e "${ARROW} ${CYAN}***   Importation data solaire et gpu   ***${NC}"
  get_solax_info

	actual_gpu_power=$(nvidia-smi -i 0 -q -d POWER | grep "Power Draw" | grep -Eo '[+-]?[0-9]+?' | head -1) 
	echo "Conso GPU actuelle : $actual_gpu_power W"
 
	actuel_gpu_power_limit=$(nvidia-smi -i 0 -q -d POWER | grep "Power Limit" | grep -Eo '[+-]?[0-9]+?' | head -1)
	echo "Power Limit GPU actuel : $actuel_gpu_power_limit W"
	echo
  
 
  echo -e "${ARROW} ${CYAN}***   Importation data EDF   ***${NC}"
  get_tempo_color

 
  echo -e "${ARROW} ${CYAN}***   Calcul puissance min et max   ***${NC}"
  set_min_max_power
 
#si surplus solaire, on augmente la puissance GPU puis le CE####################################
 
 if (($feedinpower>0))
   then
   echo -e "${ARROW} ${CYAN}***   Calcul nouvelle puissance GPU limite   ***${NC}"
    if  (($actuel_gpu_power_limit<$gpu_power_max))
      then
        newpower=$(echo $(($actuel_gpu_power_limit+$feedinpower/$gpu_nombre)))
        echo -e "${ARROW} ${CYAN}Augmentation du power limit...${NC}"
        echo "Nouveau Power Limit cible : $newpower W"
    else newpower=$actuel_gpu_power_limit
        echo "Power limit inchange"
    fi
    
    if (("$newpower" > "$gpu_power_max"))
      then   newpower=$gpu_power_max
    fi
    
    echo "Power Limit applique: $newpower W"
    echo
    
     set_powerlimit "$newpower"
    
    echo 
  
   echo -e "${ARROW} ${CYAN}***   Puissance chauffe eau   ***${NC}"
  
   CE_get
  
   if (($heure>1 & $heure<6))
      then  CE_consigne=0
  	  echo "MODE force"
   else  
      CE_consigne=$((${CE_puissance%.*}+($feedinpower-($gpu_nombre*($newpower-$actuel_gpu_power_limit)))))
  	  #else  CE_consigne=$((${CE_consigne}+($feedinpower-($gpu_nombre*($newpower-$actuel_gpu_power_limit)))))
      echo "MODE solaire"
   fi
  
   if (($CE_consigne>0))
    then CE_set "$CE_consigne"
    else CE_consigne=0
         CE_set "$CE_consigne"
   fi
 
 
 # si négatif solaire on diminue le CE puis la puissance GPU##########################################

 elif (($feedinpower<0))
   then
   echo -e "${ARROW} ${CYAN}***   Puissance chauffe eau   ***${NC}"
   CE_get
  
   if (($heure>1 & $heure<6))
      then  CE_consigne=0
  	  echo "MODE force"
   else  CE_consigne=$((${CE_puissance%.*}+$feedinpower))
      echo "MODE solaire"
   fi
  
   if (($CE_consigne>0))
      then CE_set "$CE_consigne"
   else CE_consigne=0
       CE_set "$CE_consigne"
       echo 
       echo -e "${ARROW} ${CYAN}***   Calcul nouvelle puissance GPU limite   ***${NC}"
          
          if (($actuel_gpu_power_limit>$gpu_power_min))
            then
              newpower=$(echo $(($actuel_gpu_power_limit+$((${CE_puissance%.*}+$feedinpower))/$gpu_nombre)))
              echo -e "${ARROW} ${CYAN}Baisse du power limit...${NC}"
              echo "Nouveau Power Limite cible : $newpower W"
        
          else newpower=$actuel_gpu_power_limit
              echo "Power limit inchange"
          fi
          
          if (("$newpower" < "$gpu_power_min"))
            then newpower=$gpu_power_min
          fi
          
          echo "Power Limit applique: $newpower W"
          echo
          
           set_powerlimit "$newpower"
    
    fi
  fi
 


### enregistrement log


ligne="$(echo $(date)), EDF=$tarif $tempo_color, Surplus=$feedinpower, PL min=$gpu_power_min, PL max=$gpu_power_max, PL applique=$newpower, Consigne CE=$CE_consigne, Reel CE=$CE_puissance"
 sed -i "1i$ligne" $log_file_name 


sleep $refresh_time_second

done

