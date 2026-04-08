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
