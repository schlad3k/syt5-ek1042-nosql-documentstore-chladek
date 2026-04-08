# Couchbase Document Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Spring Boot REST API with CRUD operations against a 3-node Couchbase cluster deployed via Docker Compose.

**Architecture:** A Spring Boot 3 app (Gradle) uses Spring Data Couchbase to store/retrieve `Person` documents. Three Couchbase Community nodes form a cluster via an init script. Docker Compose orchestrates all services.

**Tech Stack:** Java 21, Spring Boot 3.3, Spring Data Couchbase, Couchbase Community 7.6, Gradle 8, Docker Compose v2

---

## File Map

| File | Responsibility |
|------|---------------|
| `docker-compose.yml` | Defines 3 Couchbase nodes + Spring app service |
| `couchbase-init.sh` | Waits for Couchbase, initializes cluster, creates bucket + index |
| `Makefile` | `make up`, `make down`, `make logs`, `make test` |
| `app/build.gradle` | Gradle deps: spring-boot, spring-data-couchbase |
| `app/settings.gradle` | Project name |
| `app/src/main/resources/application.properties` | Couchbase connection config |
| `app/src/main/java/.../CouchbaseApp.java` | Spring Boot main class |
| `app/src/main/java/.../model/Person.java` | `@Document` entity |
| `app/src/main/java/.../repository/PersonRepository.java` | `CouchbaseRepository` interface |
| `app/src/main/java/.../service/PersonService.java` | Business logic, CRUD methods |
| `app/src/main/java/.../controller/PersonController.java` | REST endpoints |
| `app/src/test/java/.../PersonControllerTest.java` | MockMvc integration tests |
| `README.md` | Full documentation |

---

### Task 1: Docker Compose + Couchbase Init Script

**Files:**
- Create: `docker-compose.yml`
- Create: `couchbase-init.sh`

- [ ] **Step 1: Create `docker-compose.yml`**

```yaml
version: '3.8'

services:
  couchbase-node1:
    image: couchbase/server:community-7.6.0
    container_name: couchbase-node1
    ports:
      - "8091:8091"
      - "8093:8093"
      - "11210:11210"
    environment:
      - CLUSTER_NAME=demo-cluster
    networks:
      - couchbase-net
    volumes:
      - cb-node1-data:/opt/couchbase/var

  couchbase-node2:
    image: couchbase/server:community-7.6.0
    container_name: couchbase-node2
    networks:
      - couchbase-net
    volumes:
      - cb-node2-data:/opt/couchbase/var

  couchbase-node3:
    image: couchbase/server:community-7.6.0
    container_name: couchbase-node3
    networks:
      - couchbase-net
    volumes:
      - cb-node3-data:/opt/couchbase/var

  couchbase-init:
    image: curlimages/curl:latest
    container_name: couchbase-init
    depends_on:
      - couchbase-node1
      - couchbase-node2
      - couchbase-node3
    volumes:
      - ./couchbase-init.sh:/init.sh
    entrypoint: ["/bin/sh", "/init.sh"]
    networks:
      - couchbase-net

  spring-app:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: spring-app
    ports:
      - "8080:8080"
    environment:
      - COUCHBASE_HOST=couchbase-node1
      - COUCHBASE_USERNAME=Administrator
      - COUCHBASE_PASSWORD=password
      - COUCHBASE_BUCKET=demo
    depends_on:
      couchbase-init:
        condition: service_completed_successfully
    networks:
      - couchbase-net

networks:
  couchbase-net:
    driver: bridge

volumes:
  cb-node1-data:
  cb-node2-data:
  cb-node3-data:
```

- [ ] **Step 2: Create `couchbase-init.sh`**

```bash
#!/bin/sh
set -e

CB_HOST="couchbase-node1"
CB_USER="Administrator"
CB_PASS="password"
CB_BUCKET="demo"

wait_for_couchbase() {
  echo "Waiting for Couchbase on $CB_HOST..."
  until curl -sf "http://$CB_HOST:8091/ui/index.html" > /dev/null; do
    sleep 2
  done
  echo "Couchbase is up."
}

wait_for_couchbase

echo "Initializing cluster on node1..."
curl -sf -X POST "http://$CB_HOST:8091/clusterInit" \
  -d "hostname=couchbase-node1" \
  -d "username=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index" \
  -d "memoryQuota=512" \
  -d "indexMemoryQuota=256"

echo "Adding node2 to cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node2" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index"

echo "Adding node3 to cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/addNode" \
  -d "hostname=couchbase-node3" \
  -d "user=$CB_USER" \
  -d "password=$CB_PASS" \
  -d "services=kv,n1ql,index"

echo "Rebalancing cluster..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/controller/rebalance" \
  -d "knownNodes=ns_1@couchbase-node1,ns_1@couchbase-node2,ns_1@couchbase-node3"

sleep 5

echo "Creating bucket '$CB_BUCKET'..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8091/pools/default/buckets" \
  -d "name=$CB_BUCKET" \
  -d "bucketType=couchbase" \
  -d "ramQuota=256" \
  -d "replicaNumber=2"

sleep 3

echo "Creating primary index on '$CB_BUCKET'..."
curl -sf -u "$CB_USER:$CB_PASS" \
  -X POST "http://$CB_HOST:8093/query/service" \
  -d "statement=CREATE PRIMARY INDEX ON \`$CB_BUCKET\`"

echo "Couchbase cluster initialized successfully."
```

- [ ] **Step 3: Make init script executable and commit**

```bash
chmod +x couchbase-init.sh
git add docker-compose.yml couchbase-init.sh
git commit -m "feat: add docker compose with 3-node couchbase cluster and init script"
```

---

### Task 2: Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Create `Makefile`**

```makefile
.PHONY: up down logs test build

up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f

test:
	cd app && ./gradlew test

build:
	cd app && ./gradlew build
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "feat: add makefile"
```

---

### Task 3: Gradle Project Setup

**Files:**
- Create: `app/settings.gradle`
- Create: `app/build.gradle`
- Create: `app/Dockerfile`

- [ ] **Step 1: Create `app/settings.gradle`**

```groovy
rootProject.name = 'couchbase-demo'
```

- [ ] **Step 2: Create `app/build.gradle`**

```groovy
plugins {
    id 'org.springframework.boot' version '3.3.0'
    id 'io.spring.dependency-management' version '1.1.5'
    id 'java'
}

group = 'at.htlwrn'
version = '1.0.0'
sourceCompatibility = '21'

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-couchbase'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

test {
    useJUnitPlatform()
}
```

- [ ] **Step 3: Create `app/Dockerfile`**

```dockerfile
FROM gradle:8.7-jdk21 AS build
WORKDIR /app
COPY . .
RUN gradle bootJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- [ ] **Step 4: Initialize Gradle wrapper**

```bash
cd app && gradle wrapper --gradle-version 8.7
```

Expected: `app/gradlew`, `app/gradle/` created.

- [ ] **Step 5: Commit**

```bash
git add app/
git commit -m "feat: add gradle project scaffold with spring boot and couchbase dependency"
```

---

### Task 4: Spring Boot Main Class + Config

**Files:**
- Create: `app/src/main/java/at/htlwrn/couchbase/CouchbaseApp.java`
- Create: `app/src/main/resources/application.properties`

- [ ] **Step 1: Create main class**

```java
// app/src/main/java/at/htlwrn/couchbase/CouchbaseApp.java
package at.htlwrn.couchbase;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class CouchbaseApp {
    public static void main(String[] args) {
        SpringApplication.run(CouchbaseApp.class, args);
    }
}
```

- [ ] **Step 2: Create `application.properties`**

```properties
spring.couchbase.connection-string=${COUCHBASE_HOST:localhost}
spring.couchbase.username=${COUCHBASE_USERNAME:Administrator}
spring.couchbase.password=${COUCHBASE_PASSWORD:password}
spring.data.couchbase.bucket-name=${COUCHBASE_BUCKET:demo}
spring.data.couchbase.auto-index=true

server.port=8080
```

- [ ] **Step 3: Commit**

```bash
git add app/src/
git commit -m "feat: add spring boot main class and couchbase config"
```

---

### Task 5: Person Model

**Files:**
- Create: `app/src/main/java/at/htlwrn/couchbase/model/Person.java`

- [ ] **Step 1: Write failing test for model**

```java
// app/src/test/java/at/htlwrn/couchbase/model/PersonTest.java
package at.htlwrn.couchbase.model;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class PersonTest {

    @Test
    void personHasCorrectFields() {
        Person p = new Person();
        p.setId("person::1");
        p.setName("Max");
        p.setEmail("max@example.com");
        p.setAge(30);

        assertThat(p.getId()).isEqualTo("person::1");
        assertThat(p.getName()).isEqualTo("Max");
        assertThat(p.getEmail()).isEqualTo("max@example.com");
        assertThat(p.getAge()).isEqualTo(30);
    }
}
```

- [ ] **Step 2: Run test — expect failure**

```bash
cd app && ./gradlew test --tests "at.htlwrn.couchbase.model.PersonTest" 2>&1 | tail -10
```

Expected: `FAILED` — `Person` class not found.

- [ ] **Step 3: Create `Person.java`**

```java
// app/src/main/java/at/htlwrn/couchbase/model/Person.java
package at.htlwrn.couchbase.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.couchbase.core.mapping.Document;
import org.springframework.data.couchbase.core.mapping.Field;

@Document
public class Person {

    @Id
    private String id;

    @Field
    private String name;

    @Field
    private String email;

    @Field
    private int age;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public int getAge() { return age; }
    public void setAge(int age) { this.age = age; }
}
```

- [ ] **Step 4: Run test — expect pass**

```bash
cd app && ./gradlew test --tests "at.htlwrn.couchbase.model.PersonTest" 2>&1 | tail -10
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: Commit**

```bash
git add app/src/
git commit -m "feat: add Person document model with couchbase annotations"
```

---

### Task 6: Repository + Service

**Files:**
- Create: `app/src/main/java/at/htlwrn/couchbase/repository/PersonRepository.java`
- Create: `app/src/main/java/at/htlwrn/couchbase/service/PersonService.java`

- [ ] **Step 1: Create `PersonRepository.java`**

```java
// app/src/main/java/at/htlwrn/couchbase/repository/PersonRepository.java
package at.htlwrn.couchbase.repository;

import at.htlwrn.couchbase.model.Person;
import org.springframework.data.couchbase.repository.CouchbaseRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PersonRepository extends CouchbaseRepository<Person, String> {
}
```

- [ ] **Step 2: Create `PersonService.java`**

```java
// app/src/main/java/at/htlwrn/couchbase/service/PersonService.java
package at.htlwrn.couchbase.service;

import at.htlwrn.couchbase.model.Person;
import at.htlwrn.couchbase.repository.PersonRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class PersonService {

    private final PersonRepository repository;

    public PersonService(PersonRepository repository) {
        this.repository = repository;
    }

    public Person create(Person person) {
        person.setId("person::" + UUID.randomUUID());
        return repository.save(person);
    }

    public Optional<Person> findById(String id) {
        return repository.findById(id);
    }

    public List<Person> findAll() {
        return (List<Person>) repository.findAll();
    }

    public Optional<Person> update(String id, Person updated) {
        return repository.findById(id).map(existing -> {
            existing.setName(updated.getName());
            existing.setEmail(updated.getEmail());
            existing.setAge(updated.getAge());
            return repository.save(existing);
        });
    }

    public boolean delete(String id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return true;
        }
        return false;
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/src/
git commit -m "feat: add PersonRepository and PersonService with CRUD logic"
```

---

### Task 7: REST Controller + Tests

**Files:**
- Create: `app/src/main/java/at/htlwrn/couchbase/controller/PersonController.java`
- Create: `app/src/test/java/at/htlwrn/couchbase/controller/PersonControllerTest.java`

- [ ] **Step 1: Write failing tests**

```java
// app/src/test/java/at/htlwrn/couchbase/controller/PersonControllerTest.java
package at.htlwrn.couchbase.controller;

import at.htlwrn.couchbase.model.Person;
import at.htlwrn.couchbase.service.PersonService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(PersonController.class)
class PersonControllerTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    ObjectMapper objectMapper;

    @MockBean
    PersonService personService;

    private Person makePerson(String id, String name, String email, int age) {
        Person p = new Person();
        p.setId(id);
        p.setName(name);
        p.setEmail(email);
        p.setAge(age);
        return p;
    }

    @Test
    void createPerson_returns201() throws Exception {
        Person input = makePerson(null, "Max", "max@example.com", 30);
        Person saved = makePerson("person::1", "Max", "max@example.com", 30);
        when(personService.create(any())).thenReturn(saved);

        mockMvc.perform(post("/api/persons")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(input)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value("person::1"))
            .andExpect(jsonPath("$.name").value("Max"));
    }

    @Test
    void getPersonById_returns200() throws Exception {
        Person p = makePerson("person::1", "Max", "max@example.com", 30);
        when(personService.findById("person::1")).thenReturn(Optional.of(p));

        mockMvc.perform(get("/api/persons/person::1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Max"));
    }

    @Test
    void getPersonById_notFound_returns404() throws Exception {
        when(personService.findById("person::99")).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/persons/person::99"))
            .andExpect(status().isNotFound());
    }

    @Test
    void getAllPersons_returns200() throws Exception {
        Person p1 = makePerson("person::1", "Max", "max@example.com", 30);
        Person p2 = makePerson("person::2", "Anna", "anna@example.com", 25);
        when(personService.findAll()).thenReturn(List.of(p1, p2));

        mockMvc.perform(get("/api/persons"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void updatePerson_returns200() throws Exception {
        Person updated = makePerson("person::1", "Max Updated", "max2@example.com", 31);
        when(personService.update(eq("person::1"), any())).thenReturn(Optional.of(updated));

        mockMvc.perform(put("/api/persons/person::1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updated)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Max Updated"));
    }

    @Test
    void updatePerson_notFound_returns404() throws Exception {
        Person updated = makePerson(null, "Max", "max@example.com", 30);
        when(personService.update(eq("person::99"), any())).thenReturn(Optional.empty());

        mockMvc.perform(put("/api/persons/person::99")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updated)))
            .andExpect(status().isNotFound());
    }

    @Test
    void deletePerson_returns204() throws Exception {
        when(personService.delete("person::1")).thenReturn(true);

        mockMvc.perform(delete("/api/persons/person::1"))
            .andExpect(status().isNoContent());
    }

    @Test
    void deletePerson_notFound_returns404() throws Exception {
        when(personService.delete("person::99")).thenReturn(false);

        mockMvc.perform(delete("/api/persons/person::99"))
            .andExpect(status().isNotFound());
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
cd app && ./gradlew test --tests "at.htlwrn.couchbase.controller.PersonControllerTest" 2>&1 | tail -10
```

Expected: `FAILED` — `PersonController` not found.

- [ ] **Step 3: Create `PersonController.java`**

```java
// app/src/main/java/at/htlwrn/couchbase/controller/PersonController.java
package at.htlwrn.couchbase.controller;

import at.htlwrn.couchbase.model.Person;
import at.htlwrn.couchbase.service.PersonService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/persons")
public class PersonController {

    private final PersonService personService;

    public PersonController(PersonService personService) {
        this.personService = personService;
    }

    @PostMapping
    public ResponseEntity<Person> create(@RequestBody Person person) {
        return ResponseEntity.status(HttpStatus.CREATED).body(personService.create(person));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Person> getById(@PathVariable String id) {
        return personService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping
    public ResponseEntity<List<Person>> getAll() {
        return ResponseEntity.ok(personService.findAll());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Person> update(@PathVariable String id, @RequestBody Person person) {
        return personService.update(id, person)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        if (personService.delete(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}
```

- [ ] **Step 4: Run all tests — expect pass**

```bash
cd app && ./gradlew test 2>&1 | tail -10
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 5: Commit**

```bash
git add app/src/
git commit -m "feat: add PersonController with CRUD endpoints and MockMvc tests"
```

---

### Task 8: README Documentation

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

```markdown
# Couchbase NoSQL Document Store

INSY5 Datenmanagement — Übung: NoSQL Document Store mit Couchbase

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
```

- [ ] **Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add full README with installation, cluster docs, and CRUD examples"
```

---

### Task 9: GitHub Repository erstellen & pushen

**Files:** keine

- [ ] **Step 1: GitHub Repository erstellen**

```bash
cd /home/simon/IdeaProjects/insy5-nosql-documentstore-couchbase-chladek
gh repo create insy5-nosql-documentstore-couchbase-chladek \
  --public \
  --description "INSY5 - NoSQL Document Store mit Couchbase, Spring Boot und Docker Compose" \
  --source=. \
  --remote=origin
```

- [ ] **Step 2: Auf main umbenennen und pushen**

```bash
git branch -m master main
git push -u origin main
```

Expected: Repository unter `https://github.com/schlad3k/insy5-nosql-documentstore-couchbase-chladek` erreichbar.
