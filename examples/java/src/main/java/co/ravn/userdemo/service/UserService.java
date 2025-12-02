package co.ravn.userdemo.service;

import java.util.List;

import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.model.User;
import co.ravn.userdemo.repository.UserRepository;

import org.jspecify.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {
    private static final Logger LOGGER = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final CountryService countryService;
    private final CompanyService companyService;
    private final UserMetricsService userMetricsService;

    public UserService(UserRepository userRepository, CountryService countryService, CompanyService companyService, UserMetricsService userMetricsService) {
        this.userRepository = userRepository;
        this.countryService = countryService;
        this.companyService = companyService;
        this.userMetricsService = userMetricsService;
    }

    @Transactional
    public User create(String name, Long countryId, Long companyId) {
        LOGGER.info("Creating user with name='{}', countryId={}, companyId={}", name, countryId, companyId);

        Country country = this.countryService.findById(countryId);
        if (country == null) {
            LOGGER.error("Cannot create user: country with id={} does not exist", countryId);
            throw new IllegalArgumentException("Invalid countryId: " + countryId);
        }

        Company company = this.companyService.findById(companyId);
        if (company == null) {
            LOGGER.error("Cannot create user: company with id={} does not exist", companyId);
            throw new IllegalArgumentException("Invalid companyId: " + companyId);
        }

        try {
            User user = this.userRepository.save(new User(null, name, countryId, companyId));
            this.userMetricsService.recordUserCreated(countryId, companyId);
            LOGGER.info("User created successfully: id={}, name='{}', countryId={}, companyId={}", user.id(), user.name(), user.countryId(), user.companyId());
            return user;
        } catch (Exception e) {
            LOGGER.error("Failed to create user with name='{}', countryId={}, companyId={}", name, countryId, companyId, e);
            throw e;
        }
    }

    @Transactional
    public User update(Long id, String name, Long countryId, Long companyId) {
        LOGGER.info("Updating user with id={}, name='{}', countryId={}, companyId={}", id, name, countryId, companyId);

        User existing = findWithId(id);
        if (existing == null) {
            LOGGER.error("Cannot update user: user with id={} does not exist", id);
            throw new IllegalArgumentException("User not found: " + id);
        }

        Country country = this.countryService.findById(countryId);
        if (country == null) {
            LOGGER.error("Cannot update user: country with id={} does not exist", countryId);
            throw new IllegalArgumentException("Invalid countryId: " + countryId);
        }

        Company company = this.companyService.findById(companyId);
        if (company == null) {
            LOGGER.error("Cannot update user: company with id={} does not exist", companyId);
            throw new IllegalArgumentException("Invalid companyId: " + companyId);
        }

        try {
            User updated = this.userRepository.save(new User(id, name, countryId, companyId));
            this.userMetricsService.recordUserUpdated(existing.countryId(), existing.companyId(), countryId, companyId);
            LOGGER.info("User updated successfully: id={}, name='{}', countryId={}, companyId={}", updated.id(), updated.name(), updated.countryId(), updated.companyId());
            return updated;
        } catch (Exception e) {
            LOGGER.error("Failed to update user with id={}", id, e);
            throw e;
        }
    }

    @Transactional
    public void delete(long id) {
        LOGGER.info("Deleting user with id={}", id);

        // Fetch user before deletion to update metrics
        User existing = findWithId(id);
        if (existing == null) {
            LOGGER.warn("Cannot delete user: user with id={} does not exist", id);
            return;
        }

        try {
            this.userRepository.deleteById(id);
            this.userMetricsService.recordUserDeleted(existing.countryId(), existing.companyId());
            LOGGER.info("User deleted successfully: id={}", id);
        } catch (Exception e) {
            LOGGER.error("Failed to delete user with id={}", id, e);
            throw e;
        }
    }

    @Transactional(readOnly = true)
    public List<User> listAll() {
        LOGGER.debug("Querying database for all users");
        List<User> users = this.userRepository.findAll();
        LOGGER.info("Retrieved {} users from database", users.size());
        return users;
    }

    @Transactional(readOnly = true)
    public @Nullable User findWithId(long id) {
        LOGGER.debug("Querying database for user with id={}", id);
        User user = this.userRepository.findById(id).orElse(null);
        if (user != null) {
            LOGGER.info("Found user: id={}, name='{}'", user.id(), user.name());
        } else {
            LOGGER.info("No user found with id={}", id);
        }
        return user;
    }
}
