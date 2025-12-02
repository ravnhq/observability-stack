package co.ravn.userdemo.controller;

import java.util.List;

import co.ravn.userdemo.config.Delay;
import co.ravn.userdemo.dto.CountryDto;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.service.CountryService;
import co.ravn.userdemo.service.DtoMapperService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/api/countries", produces = MediaType.APPLICATION_JSON_VALUE)
public class CountryController {
    private static final Logger LOGGER = LoggerFactory.getLogger(CountryController.class);

    private final CountryService countryService;
    private final DtoMapperService dtoMapperService;
    private final Delay delay;

    public CountryController(CountryService countryService, DtoMapperService dtoMapperService, Delay delay) {
        this.countryService = countryService;
        this.dtoMapperService = dtoMapperService;
        this.delay = delay;
    }

    @GetMapping({"", "/"})
    public List<CountryDto> all() {
        LOGGER.debug("Received request to list all countries");
        this.delay.delay();
        List<Country> countries = this.countryService.listAll();
        List<CountryDto> countryDtos = countries.stream()
            .map(dtoMapperService::toCountryDto)
            .toList();
        LOGGER.debug("Returning {} countries", countryDtos.size());
        return countryDtos;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CountryDto> createCountry(@RequestBody CreateCountryRequest request) {
        LOGGER.info("Received request to create country with name='{}'", request.name());

        if (request.name() == null || request.name().trim().isEmpty()) {
            LOGGER.warn("Validation failed: name is null or empty");
            return ResponseEntity.badRequest().build();
        }

        this.delay.delay();

        try {
            Country createdCountry = this.countryService.create(request.name());
            CountryDto dto = this.dtoMapperService.toCountryDto(createdCountry);
            LOGGER.info("Successfully created country with id={}, name='{}'", createdCountry.id(), createdCountry.name());
            return ResponseEntity.status(HttpStatus.CREATED).body(dto);
        } catch (Exception e) {
            LOGGER.error("Failed to create country with name='{}'", request.name(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCountry(@PathVariable Long id) {
        LOGGER.info("Received request to delete country with id={}", id);
        this.delay.delay();
        try {
            this.countryService.delete(id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            LOGGER.error("Failed to delete country with id={}", id, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    public record CreateCountryRequest(String name) {}
}
