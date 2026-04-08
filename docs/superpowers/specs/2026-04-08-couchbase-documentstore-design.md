# Couchbase NoSQL Document Store — Design Spec

## Goal

Implement a Spring Boot REST API that demonstrates CRUD operations against a 3-node Couchbase cluster, deployed via Docker Compose. Documents the installation, cluster functionality, and concurrent access patterns for the INSY5 Datenmanagement assignment.

## Architecture

```
docker-compose.yml
├── couchbase-node1   (primary, Port 8091 exposed, UI accessible)
├── couchbase-node2   (joins cluster via couchbase-init.sh)
├── couchbase-node3   (joins cluster via couchbase-init.sh)
└── spring-app        (Spring Boot REST API, Port 8080)
```

- **Couchbase**: 3-node cluster initialized via shell script. Bucket `demo` with primary index created automatically.
- **Spring Boot**: Gradle project using `spring-boot-starter-data-couchbase`, exposes REST endpoints.
- **Concurrent access**: Spring's Tomcat thread pool handles multiple simultaneous HTTP requests natively.

## Data Model

`Person` document stored in Couchbase bucket `demo`:

```json
{
  "id": "person::1",
  "name": "Max Mustermann",
  "email": "max@example.com",
  "age": 30,
  "_class": "..."
}
```

## REST API

| Method | Endpoint              | Operation  |
|--------|-----------------------|------------|
| POST   | `/api/persons`        | Create     |
| GET    | `/api/persons/{id}`   | Read by ID |
| GET    | `/api/persons`        | Read All   |
| PUT    | `/api/persons/{id}`   | Update     |
| DELETE | `/api/persons/{id}`   | Delete     |

- Returns `404` if document not found
- Returns `409` on key conflict (duplicate create)

## Project Structure

```
insy5-nosql-documentstore-couchbase-chladek/
├── docker-compose.yml
├── couchbase-init.sh
├── Makefile
├── README.md
├── docs/
│   └── superpowers/
│       ├── specs/
│       └── plans/
└── app/
    ├── build.gradle
    ├── settings.gradle
    └── src/
        ├── main/java/at/htlwrn/couchbase/
        │   ├── CouchbaseApp.java
        │   ├── model/Person.java
        │   ├── repository/PersonRepository.java
        │   ├── service/PersonService.java
        │   └── controller/PersonController.java
        ├── main/resources/
        │   └── application.properties
        └── test/java/at/htlwrn/couchbase/
            └── controller/PersonControllerTest.java
```

## Tech Stack

- Java 21, Spring Boot 3.x
- Spring Data Couchbase
- Couchbase Community Server 7.x (Docker)
- Gradle 8.x
- Docker Compose v2
