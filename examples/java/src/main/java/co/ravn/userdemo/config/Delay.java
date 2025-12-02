package co.ravn.userdemo.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@EnableConfigurationProperties(UserServiceConfigurationProperties.class)
public class Delay {
    private final UserServiceConfigurationProperties properties;

    public Delay(UserServiceConfigurationProperties properties) {
        this.properties = properties;
    }

    public void delay() {
        try {
            Thread.sleep(this.properties.getDelay().toMillis());
        } catch (InterruptedException ex) {
            throw new RuntimeException("Got interrupted while sleeping", ex);
        }
    }
}
