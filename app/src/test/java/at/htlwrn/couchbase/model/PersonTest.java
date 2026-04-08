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
