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
