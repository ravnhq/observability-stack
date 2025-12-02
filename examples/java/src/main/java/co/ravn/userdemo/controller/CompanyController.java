package co.ravn.userdemo.controller;

import java.util.List;

import co.ravn.userdemo.config.Delay;
import co.ravn.userdemo.dto.CompanyDto;
import co.ravn.userdemo.dto.UserDto;
import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.User;
import co.ravn.userdemo.service.CompanyService;
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
@RequestMapping(path = "/api/companies", produces = MediaType.APPLICATION_JSON_VALUE)
public class CompanyController {
    private static final Logger LOGGER = LoggerFactory.getLogger(CompanyController.class);

    private final CompanyService companyService;
    private final DtoMapperService dtoMapperService;
    private final Delay delay;

    public CompanyController(CompanyService companyService, DtoMapperService dtoMapperService, Delay delay) {
        this.companyService = companyService;
        this.dtoMapperService = dtoMapperService;
        this.delay = delay;
    }

    @GetMapping({"", "/"})
    public List<CompanyDto> all() {
        LOGGER.debug("Received request to list all companies");
        this.delay.delay();
        List<Company> companies = this.companyService.listAll();
        List<CompanyDto> companyDtos = companies.stream()
            .map(dtoMapperService::toCompanyDto)
            .toList();
        LOGGER.debug("Returning {} companies", companyDtos.size());
        return companyDtos;
    }

    @GetMapping("/{id}/employees")
    public ResponseEntity<List<UserDto>> getEmployees(@PathVariable Long id) {
        LOGGER.debug("Received request to list employees for company id={}", id);
        this.delay.delay();

        List<User> users = this.companyService.getEmployees(id);
        List<UserDto> userDtos = users.stream()
            .map(dtoMapperService::toUserDto)
            .toList();

        LOGGER.debug("Returning {} employees for company id={}", userDtos.size(), id);
        return ResponseEntity.ok(userDtos);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CompanyDto> createCompany(@RequestBody CreateCompanyRequest request) {
        LOGGER.info("Received request to create company with name='{}', countryId={}", request.name(), request.countryId());

        if (request.name() == null || request.name().trim().isEmpty()) {
            LOGGER.warn("Validation failed: name is null or empty");
            return ResponseEntity.badRequest().build();
        }

        if (request.countryId() == null) {
            LOGGER.warn("Validation failed: countryId is null");
            return ResponseEntity.badRequest().build();
        }

        this.delay.delay();

        try {
            Company createdCompany = this.companyService.create(request.name(), request.countryId());
            CompanyDto dto = this.dtoMapperService.toCompanyDto(createdCompany);
            LOGGER.info("Successfully created company with id={}, name='{}', countryId={}", createdCompany.id(), createdCompany.name(), createdCompany.countryId());
            return ResponseEntity.status(HttpStatus.CREATED).body(dto);
        } catch (IllegalArgumentException e) {
            LOGGER.error("Validation error creating company: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            LOGGER.error("Failed to create company with name='{}', countryId={}", request.name(), request.countryId(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCompany(@PathVariable Long id) {
        LOGGER.info("Received request to delete company with id={}", id);
        this.delay.delay();
        try {
            this.companyService.delete(id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            LOGGER.error("Failed to delete company with id={}", id, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    public record CreateCompanyRequest(String name, Long countryId) {}
}
