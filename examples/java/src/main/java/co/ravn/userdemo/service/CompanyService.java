package co.ravn.userdemo.service;

import java.util.List;

import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.model.User;
import co.ravn.userdemo.repository.CompanyRepository;
import co.ravn.userdemo.repository.UserRepository;

import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CompanyService {
    private static final Logger LOGGER = LoggerFactory.getLogger(CompanyService.class);

    private final CompanyRepository companyRepository;
    private final UserRepository userRepository;
    private final CountryService countryService;

    public CompanyService(CompanyRepository companyRepository, UserRepository userRepository, CountryService countryService) {
        this.companyRepository = companyRepository;
        this.userRepository = userRepository;
        this.countryService = countryService;
    }

    @Transactional
    public Company create(String name, Long countryId) {
        LOGGER.info("Creating company with name='{}', countryId={}", name, countryId);

        Country country = this.countryService.findById(countryId);
        if (country == null) {
            LOGGER.error("Cannot create company: country with id={} does not exist", countryId);
            throw new IllegalArgumentException("Invalid countryId: " + countryId);
        }

        try {
            Company company = this.companyRepository.save(new Company(null, name, countryId));
            LOGGER.info("Company created successfully: id={}, name='{}', countryId={}", company.id(), company.name(), company.countryId());
            return company;
        } catch (Exception e) {
            LOGGER.error("Failed to create company with name='{}', countryId={}", name, countryId, e);
            throw e;
        }
    }

    @Transactional
    public void delete(long id) {
        LOGGER.info("Deleting company with id={}", id);
        try {
            this.companyRepository.deleteById(id);
            LOGGER.info("Company deleted successfully: id={}", id);
        } catch (Exception e) {
            LOGGER.error("Failed to delete company with id={}", id, e);
            throw e;
        }
    }

    @Transactional(readOnly = true)
    public List<Company> listAll() {
        LOGGER.debug("Querying database for all companies");
        List<Company> companies = this.companyRepository.findAll();
        LOGGER.info("Retrieved {} companies from database", companies.size());
        return companies;
    }

    @Transactional(readOnly = true)
    public @Nullable Company findById(long id) {
        LOGGER.debug("Querying database for company with id={}", id);
        Company company = this.companyRepository.findById(id).orElse(null);
        if (company != null) {
            LOGGER.info("Found company: id={}, name='{}', countryId={}", company.id(), company.name(), company.countryId());
        } else {
            LOGGER.info("No company found with id={}", id);
        }
        return company;
    }

    @Transactional(readOnly = true)
    public List<User> getEmployees(long companyId) {
        LOGGER.debug("Querying database for employees of company with id={}", companyId);
        List<User> users = this.userRepository.findByCompanyId(companyId);
        LOGGER.info("Retrieved {} employees for company id={}", users.size(), companyId);
        return users;
    }
}
