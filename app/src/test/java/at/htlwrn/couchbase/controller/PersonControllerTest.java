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
