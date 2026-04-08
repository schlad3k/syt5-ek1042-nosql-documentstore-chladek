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
    public ResponseEntity<Person> getById(@PathVariable("id") String id) {
        return personService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping
    public ResponseEntity<List<Person>> getAll() {
        return ResponseEntity.ok(personService.findAll());
    }

    @PutMapping("/{id}")
    public ResponseEntity<Person> update(@PathVariable("id") String id, @RequestBody Person person) {
        return personService.update(id, person)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable("id") String id) {
        if (personService.delete(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}
