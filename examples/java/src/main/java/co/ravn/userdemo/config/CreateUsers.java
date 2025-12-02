package co.ravn.userdemo.config;

import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.model.User;
import co.ravn.userdemo.service.CompanyService;
import co.ravn.userdemo.service.CountryService;
import co.ravn.userdemo.service.UserService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class CreateUsers implements CommandLineRunner {
    private static final Logger LOGGER = LoggerFactory.getLogger(CreateUsers.class);

    private final UserService userService;
    private final CountryService countryService;
    private final CompanyService companyService;

    public CreateUsers(UserService userService, CountryService countryService, CompanyService companyService) {
        this.userService = userService;
        this.countryService = countryService;
        this.companyService = companyService;
    }

    @Override
    public void run(String... args) {
        // Check if data already exists to avoid duplicates
        if (!this.countryService.listAll().isEmpty()) {
            LOGGER.info("Countries already exist, skipping data initialization");
            return;
        }

        LOGGER.info("Initializing database with sample data...");

        // Create countries
        Country usa = this.countryService.create("United States");
        LOGGER.info("USA country created with id {}", usa.id());

        Country canada = this.countryService.create("Canada");
        LOGGER.info("Canada country created with id {}", canada.id());

        Country germany = this.countryService.create("Germany");
        LOGGER.info("Germany country created with id {}", germany.id());

        // Create companies
        Company acme = this.companyService.create("Acme Corporation", usa.id());
        LOGGER.info("Acme company created with id {}", acme.id());

        Company techCo = this.companyService.create("Tech Innovations Inc", canada.id());
        LOGGER.info("Tech Innovations created with id {}", techCo.id());

        Company engineering = this.companyService.create("Engineering Solutions GmbH", germany.id());
        LOGGER.info("Engineering Solutions created with id {}", engineering.id());

        // Create users
        User moritz = this.userService.create("Moritz", germany.id(), engineering.id());
        LOGGER.info("Moritz has id {}", moritz.id());

        User andy = this.userService.create("Andy", usa.id(), acme.id());
        LOGGER.info("Andy has id {}", andy.id());

        User phil = this.userService.create("Phil", canada.id(), techCo.id());
        LOGGER.info("Phil has id {}", phil.id());

        User brian = this.userService.create("Brian", usa.id(), acme.id());
        LOGGER.info("Brian has id {}", brian.id());

        User stephane = this.userService.create("Stephane", canada.id(), techCo.id());
        LOGGER.info("Stephane has id {}", stephane.id());

        LOGGER.info("Sample data initialization completed");
    }
}
