# SolarMiningTool
Pilotage puissance de minage en fonction de la production solaire et couleur Tempo EDF


## Préalables

### Librairies  à installer :

	$ sudo apt-get update -y 
	$ sudo apt-get install -y figlet 
	$ sudo apt-get install -y jq 


### API Tempo

pour récupérer la couleur Tempo via RTE
créer un compte su <https://data.rte-france.com/>
créer une application "web/serveur" associée à l'API "Tempo Like Supply Contract"
recupérer son identifiant en cliquant sur "copier en base 64" et le coller dans SolarMiningTool.sh au niveau de la variable base64id, en "" 
