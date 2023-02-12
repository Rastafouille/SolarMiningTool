# SolarMiningTool
Pilotage puissance de minage en fonction de la production solaire et couleur Tempo EDF


## Préalables

### Librairies  à installer :
	$ sudo apt-get update -y 
	$ sudo apt-get install -y figlet 
	$ sudo apt-get install -y jq 

### API Tempo
Pour récupérer la couleur Tempo via RTE
- Créer un compte su <https://data.rte-france.com/>
- Créer une application "web/serveur" associée à l'API "Tempo Like Supply Contract"
- Recupérer son identifiant en cliquant sur "copier en base 64"

### API onduleur
Pour récupérer les valeurs de production solaire et surtout de surplus. Pour ma part j'ai un onduleur Solax Power
- Se connecter à son compte <https://www.solaxcloud.com/#/login>
- Dans Service/API récuperer son token ID et API address
- Dans Device/Inverter récupérer le Registration No. de son onduleur 

### Réglage des paramètres
Dans l'entête du script SolarMiningTool.sh éditer tous vos paramètres 

- base64="<votre identifiant api tempo en base 64>"
- solax_tokenid="<tokenid de l'APi Solax>"
- solax_sn="<Registration No. de son onduleur Solax>"

gpu_power_max=<puissance max appliquée pour 1 gpu>
gpu_power_min=<puissance min appliquée pour 1 gpu>
gpu_nombre=<nombre de gpu sur le rig>
refresh_time_second=<période de rachraichissement des puissances>

sachant que le soleil en HC ...



### lancement au démarrage

dans un screen
 screen -S solarminig solar_mining_tool.sh