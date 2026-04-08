# Couchbase NoSQL Document Store

SYT5 EK 10.4.2 — Datenmanagement: NoSQL Document Store mit Couchbase

## Über das Projekt

Dieses Projekt demonstriert die Verwendung von Couchbase als Document Store mittels einer Spring Boot REST API. 
Ein 3-Knoten-Couchbase-Cluster wird via Docker Compose bereitgestellt.

## Technologien

- **Couchbase Community Server 7.6** — NoSQL Document Store
- **Spring Boot 3.3** — REST API Framework
- **Spring Data Couchbase** — Repository-Abstraktion für Couchbase
- **Docker Compose** — Container-Orchestrierung
- **Java 21 / Gradle 8**

## Couchbase — Grundlagen

Couchbase ist ein verteilter NoSQL Document Store, der JSON-Dokumente speichert.
Jedes Dokument wird über einen eindeutigen **Key** identifiziert und in einem **Bucket** (vergleichbar mit einer Datenbank) gespeichert.

### Kernkonzepte

| Konzept | Beschreibung |
|---------|-------------|
| **Bucket** | Logische Datencontainer (wie eine Datenbank) |
| **Scope** | Namespace innerhalb eines Buckets |
| **Collection** | Gruppe von Dokumenten (wie eine Tabelle) |
| **Document** | JSON-Datensatz mit eindeutigem Key |
| **N1QL** | SQL-ähnliche Abfragesprache für Couchbase |

### Cluster-Funktionalität

Der Cluster besteht aus 3 Knoten (`couchbase-node1`, `couchbase-node2`, `couchbase-node3`).
Couchbase verteilt Daten automatisch über sogenannte **vBuckets** auf alle Knoten.

- **Replication Factor 2**: Jedes Dokument wird auf 2 weiteren Knoten repliziert
- **Automatic Failover**: Fällt ein Knoten aus, übernehmen die anderen ohne Datenverlust
- **Horizontal Scaling**: Weitere Knoten können zur Laufzeit hinzugefügt werden

Die Cluster-Verwaltung ist über das **Couchbase Web UI** unter http://localhost:8091 erreichbar
(Login: Administrator / password).

## Installation & Start

### Voraussetzungen

- Docker & Docker Compose v2
- Java 21 (nur für lokale Entwicklung ohne Docker)

### Starten

```bash
make up
```

Dies startet:
1. 3 Couchbase-Knoten
2. Init-Script (clustert die Knoten, erstellt Bucket `demo` + Primary Index)
3. Spring Boot App auf Port 8080

### Stoppen

```bash
make down
```

## CRUD API

Base URL: `http://localhost:8080/api/persons`

### Create — POST /api/persons

```bash
curl -X POST http://localhost:8080/api/persons \
  -H "Content-Type: application/json" \
  -d '{"name": "Max Mustermann", "email": "max@example.com", "age": 30}'
```

Response `201`:
```json
{"id": "person::abc-123", "name": "Max Mustermann", "email": "max@example.com", "age": 30}
```

### Read by ID — GET /api/persons/{id}

```bash
curl http://localhost:8080/api/persons/person::abc-123
```

Response `200`:
```json
{"id": "person::abc-123", "name": "Max Mustermann", "email": "max@example.com", "age": 30}
```

### Read All — GET /api/persons

```bash
curl http://localhost:8080/api/persons
```

Response `200`: Array aller Personen.

### Update — PUT /api/persons/{id}

```bash
curl -X PUT http://localhost:8080/api/persons/person::abc-123 \
  -H "Content-Type: application/json" \
  -d '{"name": "Max M.", "email": "max2@example.com", "age": 31}'
```

Response `200`: Aktualisiertes Dokument.

### Delete — DELETE /api/persons/{id}

```bash
curl -X DELETE http://localhost:8080/api/persons/person::abc-123
```

Response `204 No Content`.

## Hochverfügbarkeits-UseCase

Der 3-Knoten-Cluster mit Replication Factor 2 demonstriert Hochverfügbarkeit:

```bash
# Knoten 2 simuliert einen Ausfall
docker compose stop couchbase-node2

# API ist weiterhin erreichbar
curl http://localhost:8080/api/persons

# Knoten wieder hinzufügen
docker compose start couchbase-node2
```

Couchbase failover greift automatisch nach dem konfigurierten Timeout.

## Verteilte Architektur

Durch Verwendung der öffentlichen IP-Adresse des Hosts (statt `localhost`) kann die API
von anderen Maschinen erreicht werden. Im `docker-compose.yml` muss dazu der Port `8080`
auf `0.0.0.0:8080` gebunden werden (Standardverhalten bei Docker).

Für globale Erreichbarkeit kann z.B. `ngrok` verwendet werden:

```bash
ngrok http 8080
```

## Tests ausführen

```bash
make test
```
