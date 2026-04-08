// app/src/main/java/at/htlwrn/couchbase/repository/PersonRepository.java
package at.htlwrn.couchbase.repository;

import at.htlwrn.couchbase.model.Person;
import org.springframework.data.couchbase.repository.CouchbaseRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PersonRepository extends CouchbaseRepository<Person, String> {
}
