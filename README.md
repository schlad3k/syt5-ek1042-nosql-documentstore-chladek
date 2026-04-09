# Couchbase NoSQL Document Store

SYT5 EK 10.4.2 — Datenmanagement: NoSQL Document Store mit Couchbase

## Inhaltsverzeichnis

- [Was ist Couchbase?](#was-ist-couchbase)
- [Grundstruktur und Datenmodell](#grundstruktur-und-datenmodell)
- [Warum Couchbase?](#warum-couchbase)
- [Replikation und Hochverfügbarkeit](#replikation-und-hochverfügbarkeit)
- [Projektaufbau](#projektaufbau)
- [Installation und Start](#installation-und-start)
- [CRUD API](#crud-api)
- [Hochverfügbarkeits-Test](#hochverfügbarkeits-test)
- [Verteiltes Deployment](#verteiltes-deployment)
- [Quellen](#quellen)

---

## Was ist Couchbase?

Couchbase Server ist eine verteilte, dokumentenorientierte NoSQL-Datenbank. Sie speichert Daten als JSON-Dokumente und kombiniert die Flexibilität eines Document Stores mit der Performance eines Key-Value-Stores. Couchbase wurde für Anwendungen entwickelt, die niedrige Latenz, hohe Verfügbarkeit und horizontale Skalierbarkeit erfordern [1].

Im Gegensatz zu relationalen Datenbanken gibt es kein festes Schema — jedes Dokument kann eine unterschiedliche Struktur haben. Trotzdem bietet Couchbase mit N1QL eine SQL-ähnliche Abfragesprache, die den Einstieg für Entwickler mit SQL-Erfahrung erleichtert [2].

## Grundstruktur und Datenmodell

Couchbase organisiert Daten in einer hierarchischen Struktur:

```
Cluster
 └── Bucket          (logischer Datencontainer, vergleichbar mit einer Datenbank)
      └── Scope      (Namespace innerhalb eines Buckets)
           └── Collection  (Gruppe von Dokumenten, vergleichbar mit einer Tabelle)
                └── Document  (JSON-Datensatz mit eindeutigem Key)
```

### Kernkonzepte

| Konzept | Beschreibung |
|---------|-------------|
| **Cluster** | Verbund von Couchbase-Nodes, die gemeinsam Daten verwalten |
| **Bucket** | Logischer Datencontainer mit eigener RAM-Quote und Replikationseinstellungen |
| **Scope** | Namespace innerhalb eines Buckets (Standard: `_default`) |
| **Collection** | Sammlung von Dokumenten innerhalb eines Scopes (Standard: `_default`) |
| **Document** | JSON-Datensatz, identifiziert durch einen eindeutigen Key |
| **vBucket** | Virtueller Bucket — Couchbase partitioniert Daten in 1024 vBuckets, die auf Nodes verteilt werden [3] |

### Dienste (Services)

Couchbase trennt Workloads in unabhängige Dienste [4]:

| Service | Funktion |
|---------|----------|
| **Data (KV)** | Key-Value-Operationen, Dokumentspeicherung |
| **Query (N1QL)** | SQL-ähnliche Abfragen auf JSON-Daten |
| **Index** | Sekundärindizes für performante Abfragen |
| **Search** | Volltextsuche |
| **Analytics** | OLAP-Workloads ohne Einfluss auf operative Daten |
| **Eventing** | Serverseitige Funktionen, ausgelöst durch Datenänderungen |

### Beispiel-Dokument

```json
{
  "id": "person::f4480c70-9192-461a-a1fe-b6801252412d",
  "name": "Max Mustermann",
  "email": "max@example.com",
  "age": 30,
  "_class": "at.htlwrn.couchbase.model.Person"
}
```

## Warum Couchbase?

### Vorteile gegenüber anderen NoSQL-Datenbanken

| Eigenschaft | Couchbase | MongoDB | Redis |
|-------------|-----------|---------|-------|
| **Datenmodell** | Document + Key-Value | Document | Key-Value |
| **Abfragesprache** | N1QL (SQL-kompatibel) | MQL (eigene Syntax) | Keine (nur Befehle) |
| **Integrierter Cache** | Ja (Managed Object Cache) | Nein | Ja (ist primär Cache) |
| **Replikation** | Intra-Cluster + XDCR | Replica Sets | Sentinel/Cluster |

### Zentrale Stärken

1. **Integrierter Cache**: Couchbase hält häufig genutzte Dokumente automatisch im RAM [1]
2. **SQL-ähnliche Abfragen**: N1QL erlaubt JOINs, Aggregationen und Subqueries direkt auf JSON [2]
3. **Multi-Dimensional Scaling**: Dienste können unabhängig skaliert werden [4]
4. **Mobile Synchronisation**: Couchbase Lite ermöglicht Offline-First-Anwendungen [1]

## Replikation und Hochverfügbarkeit

### Intra-Cluster-Replikation

Couchbase verteilt Daten automatisch über alle Nodes mittels **vBuckets**. Jeder Bucket wird in 1024 vBuckets aufgeteilt, die gleichmäßig auf die Cluster-Nodes verteilt werden [3].

```
Dokument "person::abc"
   │
   ▼
 Hash-Funktion → vBucket 742
   │
   ├── Active Copy   → Node 1  (liest/schreibt)
   ├── Replica 1     → Node 2  (Backup)
   └── Replica 2     → Node 3  (Backup)
```

### Replication Factor

| Replication Factor | Kopien | Tolerierte Node-Ausfälle |
|--------------------|--------|--------------------------|
| 0 | 1 (nur Active) | 0 |
| 1 | 2 (Active + 1 Replica) | 1 |
| 2 | 3 (Active + 2 Replicas) | 2 |
| 3 | 4 (Active + 3 Replicas) | 3 |

In diesem Projekt verwenden wir **Replication Factor 2** bei einem 3-Node-Cluster (Docker Compose) bzw. **Replication Factor 1** bei einem 2-Node-Cluster (verteiltes Deployment). [5]

### Automatic Failover

Wenn ein Node ausfällt, erkennt Couchbase dies und aktiviert die Replica-vBuckets auf den verbleibenden Nodes [5]:

```
Normalzustand:
  Node 1: vBucket 742 (Active)
  Node 2: vBucket 742 (Replica)

Node 1 fällt aus → Automatic Failover:
  Node 2: vBucket 742 (Active ← promoted)
```

### Cross-Datacenter Replication (XDCR)

Für geographisch verteilte Deployments bietet Couchbase **XDCR** — eine asynchrone Replikation zwischen separaten Clustern. Nur in der Enterprise Edition verfügbar. [6]

## Projektaufbau

### Technologien

- **Couchbase Community Server 7.6** — NoSQL Document Store
- **Spring Boot 3.3** — REST API Framework
- **Spring Data Couchbase** — Repository-Abstraktion für Couchbase
- **Docker Compose** — Container-Orchestrierung
- **Java 21 / Gradle 8**

### Projektstruktur

```
syt5-ek1042-nosql-documentstore-chladek/
├── .env.example                # Konfigurierbare Umgebungsvariablen
├── docker-compose.yml          # 3 Couchbase-Nodes + Init + Spring App
├── couchbase-init.sh           # Cluster-Setup via REST API
├── Makefile                    # Shortcuts (make up/down/logs/test)
└── app/
    ├── Dockerfile              # Multi-Stage Build (Gradle → JRE)
    ├── build.gradle            # Spring Boot 3.3 + Spring Data Couchbase
    └── src/main/java/at/htlwrn/couchbase/
        ├── CouchbaseApp.java           # Spring Boot Entry Point
        ├── model/Person.java           # @Document Entity
        ├── repository/PersonRepository.java  # CouchbaseRepository Interface
        ├── service/PersonService.java        # CRUD Business Logic
        └── controller/PersonController.java  # REST Endpoints
```

## Installation und Start

### Voraussetzungen

- Docker & Docker Compose v2
- Java 21 (nur für lokale Entwicklung ohne Docker)

### Konfiguration

```bash
cp .env.example .env
# Bei Bedarf Werte in .env anpassen (Passwort, Ports, Memory-Quotas)
```

### Starten

```bash
make up
```

Dies startet:
1. 3 Couchbase-Nodes (mit statischen IPs im Docker-Netzwerk)
2. Init-Script (konfiguriert Cluster, fügt Nodes hinzu, erstellt Bucket + Primary Index)
3. Spring Boot App auf dem konfigurierten Port (Standard: 8080)

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

### Read All — GET /api/persons

```bash
curl http://localhost:8080/api/persons
```

### Read by ID — GET /api/persons/{id}

```bash
curl http://localhost:8080/api/persons/person::abc-123
```

### Update — PUT /api/persons/{id}

```bash
curl -X PUT http://localhost:8080/api/persons/person::abc-123 \
  -H "Content-Type: application/json" \
  -d '{"name": "Max M.", "email": "max2@example.com", "age": 31}'
```

### Delete — DELETE /api/persons/{id}

```bash
curl -X DELETE http://localhost:8080/api/persons/person::abc-123
```

## Hochverfügbarkeits-Test

```bash
# 1. Testdaten anlegen
curl -X POST http://localhost:8080/api/persons \
  -H "Content-Type: application/json" \
  -d '{"name": "HA Test", "email": "ha@test.com", "age": 1}'

# 2. Node stoppen
docker compose stop couchbase-node2

# 3. API ist weiterhin erreichbar
curl http://localhost:8080/api/persons

# 4. Node wieder starten
docker compose start couchbase-node2
```

## Tests ausführen

```bash
make test
```

## Verteiltes Deployment

Für ein Deployment über mehrere physische Maschinen (z.B. Laptop + Cloud-VM) wird **Tailscale** als Mesh-VPN verwendet, da die Rechner hinter NAT stehen.

### Voraussetzungen

- [Tailscale](https://tailscale.com/download) auf allen Maschinen installiert und verbunden
- Docker (native, nicht Docker Desktop) auf jedem Rechner

### Setup (2-Node Beispiel)

```bash
# Tailscale-IPs ermitteln
tailscale ip -4   # z.B. 100.108.45.74 (Laptop), 100.116.29.101 (VM)
```

**Auf jedem Rechner — Couchbase starten:**

```bash
docker run -d --name couchbase --network host couchbase/server:community-7.6.0
```

**Cluster bilden (von Node 1 aus):**

```bash
NODE1=100.108.45.74
NODE2=100.116.29.101

# Node 1 initialisieren
curl -X POST "http://$NODE1:8091/node/controller/rename" -d "hostname=$NODE1"
curl -X POST "http://$NODE1:8091/node/controller/setupServices" -d "services=kv%2Cn1ql%2Cindex"
curl -X POST "http://$NODE1:8091/pools/default" -d "memoryQuota=512&indexMemoryQuota=256"
curl -X POST "http://$NODE1:8091/settings/web" -d "username=Administrator&password=password&port=8091"

sleep 10

# Node 2 hinzufügen + Rebalance
curl -u Administrator:password -X POST "http://$NODE1:8091/controller/addNode" \
  -d "hostname=$NODE2&user=Administrator&password=password&services=kv%2Cn1ql%2Cindex"

curl -u Administrator:password -X POST "http://$NODE1:8091/controller/rebalance" \
  -d "knownNodes=ns_1%40$NODE1%2Cns_1%40$NODE2"

sleep 30

# Bucket + Index
curl -u Administrator:password -X POST "http://$NODE1:8091/pools/default/buckets" \
  -d "name=demo&bucketType=couchbase&ramQuota=256&replicaNumber=1"

sleep 10

curl -u Administrator:password -X POST "http://$NODE1:8091/settings/indexes" -d "storageMode=forestdb"
curl -u Administrator:password -X POST "http://$NODE1:8093/query/service" \
  -d "statement=CREATE%20PRIMARY%20INDEX%20ON%20%60demo%60"

# Auto-Failover aktivieren (30s Timeout)
curl -u Administrator:password -X POST "http://$NODE1:8091/settings/autoFailover" \
  -d "enabled=true&timeout=30"
```

**Spring Boot App starten:**

```bash
./gradlew bootRun --args='--spring.couchbase.connection-string=couchbase://100.108.45.74 --server.port=9090'
```

### Failover testen

```bash
# Daten anlegen
curl -X POST http://localhost:9090/api/persons \
  -H "Content-Type: application/json" \
  -d '{"name": "Failover Test", "email": "fail@test.com", "age": 1}'

# Node 2 stoppen (auf der VM)
ssh ubuntu@<VM_IP> "docker stop couchbase"

# Manueller Failover (oder 30s warten für Auto-Failover)
curl -u Administrator:password -X POST "http://100.108.45.74:8091/controller/failOver" \
  -d "otpNode=ns_1%40100.116.29.101"

# Daten sind noch verfügbar
curl http://localhost:9090/api/persons
```

## Quellen

[1] Couchbase Inc., "Why Couchbase?", https://docs.couchbase.com/server/current/introduction/why-couchbase.html

[2] Couchbase Inc., "N1QL Language Reference", https://docs.couchbase.com/server/current/n1ql/n1ql-language-reference/index.html

[3] Couchbase Inc., "vBuckets", https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/vbuckets.html

[4] Couchbase Inc., "Services and Indexes", https://docs.couchbase.com/server/current/learn/services-and-indexes/services/services.html

[5] Couchbase Inc., "Intra-Cluster Replication", https://docs.couchbase.com/server/current/learn/clusters-and-availability/intra-cluster-replication.html

[6] Couchbase Inc., "Cross Data Center Replication (XDCR)", https://docs.couchbase.com/server/current/learn/clusters-and-availability/xdcr-overview.html
