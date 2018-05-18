package fr.apside.entretien.countryapi.hello;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController
public class HelloController {

    @RequestMapping("/")
    public String index() {
        return "Spring Boot with Apside !";
    }

}

