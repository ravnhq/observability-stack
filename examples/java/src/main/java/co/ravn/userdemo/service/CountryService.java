package co.ravn.userdemo.service;

import java.util.List;

import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.repository.CountryRepository;

import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CountryService {
    private static final Logger LOGGER = LoggerFactory.getLogger(CountryService.class);

    private final CountryRepository countryRepository;

    public CountryService(CountryRepository countryRepository) {
        this.countryRepository = countryRepository;
    }

    @Transactional
    public Country create(String name) {
        LOGGER.info("Creating country with name='{}'", name);
        try {
            Country country = this.countryRepository.save(new Country(null, name));
            LOGGER.info("Country created successfully: id={}, name='{}'", country.id(), country.name());
            return country;
        } catch (Exception e) {
            LOGGER.error("Failed to create country with name='{}'", name, e);
            throw e;
        }
    }

    @Transactional
    public void delete(long id) {
        LOGGER.info("Deleting country with id={}", id);
        try {
            this.countryRepository.deleteById(id);
            LOGGER.info("Country deleted successfully: id={}", id);
        } catch (Exception e) {
            LOGGER.error("Failed to delete country with id={}", id, e);
            throw e;
        }
    }

    @Transactional(readOnly = true)
    public List<Country> listAll() {
        LOGGER.debug("Querying database for all countries");
        List<Country> countries = this.countryRepository.findAll();
        LOGGER.info("Retrieved {} countries from database", countries.size());
        return countries;
    }

    @Transactional(readOnly = true)
    public @Nullable Country findById(long id) {
        LOGGER.debug("Querying database for country with id={}", id);
        Country country = this.countryRepository.findById(id).orElse(null);
        if (country != null) {
            LOGGER.info("Found country: id={}, name='{}'", country.id(), country.name());
        } else {
            LOGGER.info("No country found with id={}", id);
        }
        return country;
    }
}
