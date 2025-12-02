package co.ravn.userdemo.config;

import co.ravn.userdemo.model.User;
import co.ravn.userdemo.repository.UserRepository;
import co.ravn.userdemo.service.CompanyService;
import co.ravn.userdemo.service.CountryService;
import co.ravn.userdemo.service.UserMetricsService;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class MetricsConfiguration {

    /**
     * Define UserMetricsService bean.
     * Spring will auto-inject dependencies.
     */
    @Bean
    public UserMetricsService userMetricsService(
            MeterRegistry meterRegistry,
            CompanyService companyService,
            CountryService countryService) {
        return new UserMetricsService(meterRegistry, companyService, countryService);
    }

    /**
     * Initialize metrics on application startup.
     * Loads existing users from database and registers gauges.
     */
    @Bean
    public CommandLineRunner initializeUserMetrics(
            UserMetricsService userMetricsService,
            UserRepository userRepository) {
        return args -> {
            List<User> existingUsers = userRepository.findAll();
            userMetricsService.initializeMetrics(existingUsers);
        };
    }
}
