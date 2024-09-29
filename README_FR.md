# HTTP Benchmarking avec `wrk` et script Lua

Ce document explique comment utiliser `wrk` avec un script Lua afin de réaliser des tests de performance HTTP sur plusieurs URLs.

## Présentation de `wrk`

[wrk](https://github.com/wg/wrk) est un outil de benchmarking HTTP très performant qui peut générer un grand nombre de requêtes en simultané. Il permet de tester la capacité de charge des serveurs et d'obtenir des statistiques détaillées sur les performances.

### Commande

Utilisez le Dockerfile afin de build votre image docker de `wrk` : `docker build -t wrk:latest .`

```bash
docker run -v ./scripts:/data wrk -t <threads> -c <connections> -d <duration> -s <script.lua> <url>
```

```text
-c, --connections: Nombre total de connexions HTTP à maintenir ouvertes. 
                   Chaque thread gère N = connexions/threads.

-d, --duration:    duration of the test, e.g. 2s, 2m, 2h

-t, --threads:     Nombre de threads à utiliser. Chaque thread est responsable 
                   de la gestion des connexions.

-s, --script:      Script Lua utilisé pour personnaliser les requêtes, 
                   comme celui que nous détaillons ci-dessous.

-H, --header:      Ajouter un en-tête HTTP aux requêtes. Avec notre script,
                   ceci n'est pas nécessaire car les en-têtes peuvent être 
                   géré directement dans le script.

    --latency:     Affiche des statistiques détaillées sur la latence. 
                   Cette option est déjà gérée dans le script, donc inutile ici.

    --timeout:     Durée après laquelle une requête échoue si
                   aucune réponse n'est reçue. La valeur par 
                   défaut est de 2 secondes.
```

### Impact des paramètres `-c` et `-t`

- **`-c, --connections`** : Définit le nombre total de connexions HTTP à maintenir ouvertes. Chaque thread gère un certain nombre de connexions, déterminé par `N = connections / threads`, donc si vous avez `-c 100 -t 4`, chaque thread gère 25 connexions. Un nombre de connexions plus élevé permet de tester comment le serveur gère une forte charge simultanée, mais cela peut aussi surcharger le client ou le serveur si la valeur est trop haute.
  
- **`-t, --threads`** : Définit le nombre total de threads utilisés. Chaque thread exécute des requêtes HTTP en parallèle. Un plus grand nombre de threads permet de maximiser la génération de requêtes simultanées, mais cela dépend aussi des capacités du CPU et des limites du système.

### Limitations

- Dans le script Lua, la fonction response() ne donne pas le chemin testé, on ne peut pas suivre les réponses par chemin, mais au global uniquement
- Il faut adapter le nombre de `connections` et `threads` aux capacités du CPU de la machine
- Tester en local une URL ne donnera pas les mêmes résultats que depuis internet
- La qualité de la connexion internet impact les résultats
- La carte réseau, sur les tests avec beaucoup de connexion simultanée, peut ne pas être capable de toutes les traiter

### Script Lua pour `wrk`

Ce script permet de :

- Envoyer des requêtes à plusieurs URLs simultanément
- Suivre le nombre de requêtes par URL
- Simuler des délais aléatoires entre les requêtes pour des connexions plus réalistes
- Exporter les statistiques dans un fichier JSON

Les valeurs que vous pouvez modifier sont au début du script :

```text
local urls = {
   { path = "/", method = "GET", headers = nil, body = nil },
   { path = "/stories", method = "GET", headers = nil, body = nil },
   { path = "/products", method = "GET", headers = nil, body = nil },
   { path = "https://www.google.com", method = "GET", headers = nil, body = nil }
}
local min_delay_ms = 10
local max_delay_ms = 100
local range_latency = { 50, 75, 95, 99.99 }
local filename = "wrk_summary"
```

Exemple : `docker run -v ./scripts:/data wrk -s multi_http.lua -c 100 -t 4 -d 5 --timeout 2s https://about.google/`

Résultats en json:

```json
{
    "data_received_MB": 41.15,
    "data_received_MB_per_second": 8.05,
    "errors": {
        "non_2xx_or_3xx_responses": 648,
        "timeouts": 134
    },
    "latency_percentiles_in_ms": {
        "50th": 116.61,
        "75th": 186.09,
        "95th": 355.12,
        "99.99th": 764.28
    },
    "requests_per_second": 477.52,
    "response_success_percentage": 97.87,
    "total_requests": 2494,
    "total_responses": 2441,
    "url_requests": {
        "/": 681,
        "/products": 610,
        "/stories": 546,
        "https://www.google.com": 657
    }
}
```
