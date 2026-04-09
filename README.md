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
