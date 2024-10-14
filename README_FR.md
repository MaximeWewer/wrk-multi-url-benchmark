# HTTP Benchmarking avec `wrk` et script Lua

Ce document explique comment utiliser `wrk` avec un script Lua afin de réaliser des tests de performance HTTP sur plusieurs URLs.

## Présentation de `wrk`

[wrk](https://github.com/wg/wrk) est un outil de benchmarking HTTP très performant qui peut générer un grand nombre de requêtes en simultané. Il permet de tester la capacité de charge des serveurs et d'obtenir des statistiques détaillées sur les performances.

## Prérequis

Assurez-vous que les outils suivants sont installés sur votre ordinateur :

- Docker
- Jq

Le script vérifiera automatiquement l'installation de Docker et de Jq avant d'exécuter le benchmark.

## Créer une image Docker WRK

Utilisez le Dockerfile pour créer votre image Docker `wrk` : `docker build -t wrk:latest .`

## Usage du script

```bash
./run_wrk.sh [options]
```

### Exemple

```bash
./run_wrk.sh --connections 100 --threads 4 --duration 30s --url https://example.com
```

### Options

```text
--connections    Total number of connections (default: 100)"
--threads        Number of threads (default: 2)"
--duration       Test duration (default: 10s)"
--script         Lua script to use (default: multi_http.lua)"
--timeout        Request timeout (default: 2s)"
--min-delay      Minimum delay in ms (default: 10)"
--max-delay      Maximum delay in ms (default: 100)"
--range-latency  Latency range (default: 50,75,95,99.99)"
--filename       Output file name (default: wrk_results)"
--show-stdout    Do not display stdout results (default: false)"
--url            Target URL (default: https://about.google/). 
                 To test multiple URLs, you need to edit this bash."
```

### Impact des paramètres `--connections` et `--threads`

- **`--connections`** : Définit le nombre total de connexions HTTP à maintenir ouvertes. Chaque thread gère un certain nombre de connexions, déterminé par `N = connections / threads`, donc si vous avez `-c 100 -t 4`, chaque thread gère 25 connexions. Un nombre de connexions plus élevé permet de tester comment le serveur gère une forte charge simultanée, mais cela peut aussi surcharger le client ou le serveur si la valeur est trop haute.
  
- **`--threads`** : Définit le nombre total de threads utilisés. Chaque thread exécute des requêtes HTTP en parallèle. Un plus grand nombre de threads permet de maximiser la génération de requêtes simultanées, mais cela dépend aussi des capacités du CPU et des limites du système.

### Script Lua pour `wrk`

Le script `multi_http.lua` permet de :

- Envoyer des requêtes à plusieurs URLs simultanément et leur donner un poid d'importance
- Suivre le nombre de requêtes par URL
- Simuler des délais aléatoires entre les requêtes pour des connexions plus réalistes
- Exporter les statistiques dans un fichier JSON

Le script crée un fichier de configuration `wrk_config.txt` dans le répertoire `./scripts`, qui est utilisé par le script Lua. Ce fichier contient les paramètres suivants :

```text
urls = {
    { path = "/", method = "GET", headers = nil, body = nil, weight = 100 }
}
min_delay_ms = [min_delay_value]
max_delay_ms = [max_delay_value]
stdout_result = [true|false]
connections = [number_of_connections]
threads = [number_of_threads]
range_latency = [latency_percentiles]
filename = [output_filename]
```

### Limitations

- Dans le script Lua, la fonction response() ne donne pas le chemin testé, on ne peut pas suivre les réponses par chemin, mais au global uniquement
- Il faut adapter le nombre de `connections` et `threads` aux capacités du CPU de la machine
- Tester en local une URL ne donnera pas les mêmes résultats que depuis internet
- La qualité de la connexion internet impact les résultats
- La carte réseau, sur les tests avec beaucoup de connexion simultanée, peut ne pas être capable de toutes les traiter

## Résultat en JSON

Les résultats du test sont enregistrés sous forme de fichier JSON, qui contient des statistiques détaillées du test. Un exemple de résultat :

```json
{
  "data_received_MB": 66.49,
  "data_received_MB_per_second": 6.65,
  "errors": {
    "non_2xx_or_3xx_responses": 1024,
    "timeouts": 139
  },
  "latency_percentiles_in_ms": {
    "50th": 119.78,
    "75th": 289.26,
    "95th": 474.54,
    "99.99th": 879.1
  },
  "nb_connections": 100,
  "nb_threads": 2,
  "requests_per_second": 408.06,
  "response_success_percentage": 97.86,
  "total_requests": 4168,
  "total_responses": 4079,
  "url_requests": {
    "/": 1113,
    "/products": 994,
    "/stories": 1025,
    "https://www.google.com": 1036
  }
}
```
