package co.ravn.userdemo.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.model.User;

import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class UserMetricsService {
    private static final Logger LOGGER = LoggerFactory.getLogger(UserMetricsService.class);

    private final MeterRegistry meterRegistry;
    private final CompanyService companyService;
    private final CountryService countryService;

    // Track user counts for gauges
    private final ConcurrentHashMap<String, AtomicInteger> companyUserCounts;
    private final ConcurrentHashMap<String, AtomicInteger> countryUserCounts;

    // Track registered gauges to prevent duplicates
    private final Set<String> registeredGauges;

    public UserMetricsService(MeterRegistry meterRegistry,
                            CompanyService companyService,
                            CountryService countryService) {
        this.meterRegistry = meterRegistry;
        this.companyService = companyService;
        this.countryService = countryService;
        this.companyUserCounts = new ConcurrentHashMap<>();
        this.countryUserCounts = new ConcurrentHashMap<>();
        this.registeredGauges = ConcurrentHashMap.newKeySet();
    }

    /**
     * Initialize metrics from existing users in database.
     * Should be called once on application startup.
     */
    public void initializeMetrics(List<User> existingUsers) {
        LOGGER.info("Initializing user metrics for {} existing users", existingUsers.size());

        for (User user : existingUsers) {
            incrementGaugeCounter(user.countryId(), user.companyId());
        }

        LOGGER.debug("User metrics initialized: {} companies tracked, {} countries tracked",
            companyUserCounts.size(), countryUserCounts.size());
    }

    /**
     * Record a user creation event.
     * Increments gauge counters and create counter.
     */
    public void recordUserCreated(Long countryId, Long companyId) {
        Country country = countryService.findById(countryId);
        Company company = companyService.findById(companyId);

        if (country == null || company == null) {
            LOGGER.warn("Cannot record user creation: country or company not found (countryId={}, companyId={})",
                countryId, companyId);
            return;
        }

        String companyName = company.name();
        String countryName = country.name();

        // Increment gauges
        incrementGaugeCounter(countryId, companyId);

        // Increment create counter
        incrementCreateCounter(companyName, countryName);

        LOGGER.debug("Recorded user creation: company='{}', country='{}'", companyName, countryName);
    }

    /**
     * Record a user deletion event.
     * Decrements gauge counters and increments delete counter.
     */
    public void recordUserDeleted(Long countryId, Long companyId) {
        Country country = countryService.findById(countryId);
        Company company = companyService.findById(companyId);

        if (country == null || company == null) {
            LOGGER.warn("Cannot record user deletion: country or company not found (countryId={}, companyId={})",
                countryId, companyId);
            return;
        }

        String companyName = company.name();
        String countryName = country.name();

        // Decrement gauges
        decrementGaugeCounter(countryId, companyId);

        // Increment delete counter
        incrementDeleteCounter(companyName, countryName);

        LOGGER.debug("Recorded user deletion: company='{}', country='{}'", companyName, countryName);
    }

    /**
     * Record a user update event.
     * Updates gauge counters if location changed and increments update counter.
     */
    public void recordUserUpdated(Long oldCountryId, Long oldCompanyId,
                                 Long newCountryId, Long newCompanyId) {
        Country newCountry = countryService.findById(newCountryId);
        Company newCompany = companyService.findById(newCompanyId);

        if (newCountry == null || newCompany == null) {
            LOGGER.warn("Cannot record user update: new country or company not found (countryId={}, companyId={})",
                newCountryId, newCompanyId);
            return;
        }

        String newCompanyName = newCompany.name();
        String newCountryName = newCountry.name();

        LOGGER.debug("Recording user update: old (country={}, company={}) -> new (country={}, company={})",
            oldCountryId, oldCompanyId, newCountryId, newCompanyId);

        // Check if location changed
        boolean countryChanged = !oldCountryId.equals(newCountryId);
        boolean companyChanged = !oldCompanyId.equals(newCompanyId);

        if (countryChanged || companyChanged) {
            // Decrement old location gauges
            decrementGaugeCounter(oldCountryId, oldCompanyId);

            // Increment new location gauges
            incrementGaugeCounter(newCountryId, newCompanyId);
        }

        // Always increment update counter (even for in-place updates)
        incrementUpdateCounter(newCompanyName, newCountryName);

        LOGGER.debug("Recorded user update: company='{}', country='{}'", newCompanyName, newCountryName);
    }

    /**
     * Increment gauge counters for a company and country.
     * Lazily registers gauges if this is the first user for the company/country.
     */
    private void incrementGaugeCounter(Long countryId, Long companyId) {
        Country country = countryService.findById(countryId);
        Company company = companyService.findById(companyId);

        if (country == null || company == null) {
            LOGGER.warn("Cannot increment gauge: country or company not found (countryId={}, companyId={})",
                countryId, companyId);
            return;
        }

        String companyName = company.name();
        String countryName = country.name();

        // Increment company count
        AtomicInteger companyCounter = companyUserCounts.computeIfAbsent(companyName, k -> {
            AtomicInteger counter = new AtomicInteger(0);
            registerCompanyGauge(companyName, countryName, counter);
            return counter;
        });
        companyCounter.incrementAndGet();

        // Increment country count
        AtomicInteger countryCounter = countryUserCounts.computeIfAbsent(countryName, k -> {
            AtomicInteger counter = new AtomicInteger(0);
            registerCountryGauge(countryName, counter);
            return counter;
        });
        countryCounter.incrementAndGet();

        LOGGER.debug("Incremented gauge counters: company='{}' ({}), country='{}' ({})",
            companyName, companyCounter.get(), countryName, countryCounter.get());
    }

    /**
     * Decrement gauge counters for a company and country.
     */
    private void decrementGaugeCounter(Long countryId, Long companyId) {
        Country country = countryService.findById(countryId);
        Company company = companyService.findById(companyId);

        if (country == null || company == null) {
            LOGGER.warn("Cannot decrement gauge: country or company not found (countryId={}, companyId={})",
                countryId, companyId);
            return;
        }

        String companyName = company.name();
        String countryName = country.name();

        // Decrement company count
        AtomicInteger companyCounter = companyUserCounts.get(companyName);
        if (companyCounter != null) {
            int newValue = companyCounter.decrementAndGet();
            LOGGER.debug("Decremented gauge counter for company='{}': {}", companyName, newValue);
        }

        // Decrement country count
        AtomicInteger countryCounter = countryUserCounts.get(countryName);
        if (countryCounter != null) {
            int newValue = countryCounter.decrementAndGet();
            LOGGER.debug("Decremented gauge counter for country='{}': {}", countryName, newValue);
        }
    }

    /**
     * Register a gauge for company user count.
     * Prevents duplicate registration using registeredGauges set.
     */
    private void registerCompanyGauge(String companyName, String countryName, AtomicInteger counter) {
        String gaugeKey = "company:" + companyName;

        if (registeredGauges.add(gaugeKey)) {
            Gauge.builder("users.count.by.company", counter, AtomicInteger::get)
                 .tag("company.name", companyName)
                 .tag("country.name", countryName)
                 .description("Number of users in company")
                 .register(meterRegistry);

            LOGGER.info("Registered gauge for company='{}', country='{}'", companyName, countryName);
        }
    }

    /**
     * Register a gauge for country user count.
     * Prevents duplicate registration using registeredGauges set.
     */
    private void registerCountryGauge(String countryName, AtomicInteger counter) {
        String gaugeKey = "country:" + countryName;

        if (registeredGauges.add(gaugeKey)) {
            Gauge.builder("users.count.by.country", counter, AtomicInteger::get)
                 .tag("country.name", countryName)
                 .description("Number of users in country")
                 .register(meterRegistry);

            LOGGER.info("Registered gauge for country='{}'", countryName);
        }
    }

    /**
     * Increment the create counter for a company and country.
     */
    private void incrementCreateCounter(String companyName, String countryName) {
        Counter.builder("users.created.total")
               .tag("company.name", companyName)
               .tag("country.name", countryName)
               .description("Total number of users created")
               .register(meterRegistry)
               .increment();
    }

    /**
     * Increment the delete counter for a company and country.
     */
    private void incrementDeleteCounter(String companyName, String countryName) {
        Counter.builder("users.deleted.total")
               .tag("company.name", companyName)
               .tag("country.name", countryName)
               .description("Total number of users deleted")
               .register(meterRegistry)
               .increment();
    }

    /**
     * Increment the update counter for a company and country.
     */
    private void incrementUpdateCounter(String companyName, String countryName) {
        Counter.builder("users.updated.total")
               .tag("company.name", companyName)
               .tag("country.name", countryName)
               .description("Total number of users updated")
               .register(meterRegistry)
               .increment();
    }
}
