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

Le script Lua `multi_http.lua` permet de tester plusieurs URLs avec des requêtes aléatoires, de suivre le nombre de requêtes par URL, et de collecter des statistiques sur les réponses et la latence. Il simule également des délais aléatoires entre les requêtes pour refléter des connexions plus réalistes.

Il y a des valeurs (**urls**, **delay_ms**, **range_latency**) qui peuvent être modifiées dans le script selon vos besoins.

Exemple : `docker run -v ./scripts:/data wrk -c 5 -t 2 -d 5 -s multi_http.lua --timeout 2s https://about.google/`

Résultats :

```text
Running 5s test @ https://about.google/
  2 threads and 5 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    63.13ms   27.56ms 164.19ms   74.03%
    Req/Sec    15.52      6.86    30.00     86.67%
  158 requests in 4.59s, 2.70MB read
  Socket errors: connect 0, read 0, write 0, timeout 4
  Non-2xx or 3xx responses: 40
Requests/sec:     34.40
Transfer/sec:    601.36KB
--------------------------------------------------------
URL '/' was requested 22 times
URL '/stories' was requested 17 times
URL '/products' was requested 15 times
URL 'https://www.google.com' was requested 29 times
Thread 1 made 83 requests and handled 80 responses (96.39%)

URL '/' was requested 22 times
URL '/stories' was requested 20 times
URL '/products' was requested 22 times
URL 'https://www.google.com' was requested 15 times
Thread 2 made 79 requests and handled 78 responses (98.73%)

Total made 162 requests and handled 158 responses (97.53%)

Latency Percentiles (in ms):
  50th percentile: 52 ms
  75th percentile: 82 ms
  95th percentile: 116 ms
  99.99th percentile: 164 ms
```
