# SolarMiningTool
Pilotage de la puissance de minage en fonction de la production solaire et couleur Tempo EDF du jour

<img src="Capture.jpg" width="500"/>

L'idée est de réguler la puissanse électrique pour gérer le surplus solaire en restant dans des bornes min et max de puissance.
Par exemple pour ma part, en jour bleue et blanc je mine à 250W par carte et autorise à monter à 300W si surplus de production solaire. 
Par contre, en jour rouge, plutôt de 100W à 300W, voire même éteindre le worker (implémentation en cours) ou carrément éteindre le rig via une prise connectée 
(si je me chauffe je regarde...) 


## Préalables

Passer le script en executable

	$ chmod +x SolarMiningTool.sh
	
### Librairies  à installer :
	$ sudo apt-get update -y 
	$ sudo apt-get install -y figlet 
	$ sudo apt-get install -y jq 
	$ sudo apt install screen

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

Modifier le fichier .json en remplacant les "xxx" par vos valeurs et renommer en ApiData.json
- base64="<votre identifiant api tempo en base 64>"
- solax_tokenid="<tokenid de l'APi Solax>"
- solax_sn="<période de rachraichissement des puissances>"

Dans l'entête du script SolarMiningTool.sh éditer tous vos paramètres :
- gpu_nombre=<période de rachraichissement des puissances>
- refresh_time_second=<période de rachraichissement des puissances>

Puis toutes les puissances que vous souhaitez en fonction de la couleur tempo et le tarif HC ou HP

Sachant que le soleil en HC ...

### lancement au démarrage

Pour que le script se lance dans un screen au démarrage

	$ sudo nano /etc/rc.local
	
Ajouter

	$ screen -S SolarMiningTool /home/user/SolarMiningTool/SolarMiningTool.sh
 
NE MARCHE PAS ....

 Tentative en cours avec systemd
 
	$ /etc/systemd/system/SolarMiningTool.service
	$ systemctl daemon-reload
	$ systemctl start SolarMiningTool.service
	$ sudo journalctl -u SolarMiningTool.service

 
