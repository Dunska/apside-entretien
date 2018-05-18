package fr.apside.entretien.countryapi.country;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@CrossOrigin
@RestController
@RequestMapping(value = "/country")
public class CountryController {

    CountryRepository countryRepository;

    public CountryController(CountryRepository countryRepository) {
        this.countryRepository = countryRepository;
    }

    @RequestMapping("/")
    public Iterable<Country> all() {
        return countryRepository.findAll();
    }
}
