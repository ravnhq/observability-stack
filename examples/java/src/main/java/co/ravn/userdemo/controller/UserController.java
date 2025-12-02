package co.ravn.userdemo.controller;

import java.util.List;

import co.ravn.userdemo.config.Delay;
import co.ravn.userdemo.dto.UserDto;
import co.ravn.userdemo.model.User;
import co.ravn.userdemo.service.DtoMapperService;
import co.ravn.userdemo.service.UserService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/api", produces = MediaType.APPLICATION_JSON_VALUE)
public class UserController {
    private static final Logger LOGGER = LoggerFactory.getLogger(UserController.class);

    private final UserService userService;
    private final DtoMapperService dtoMapperService;
    private final Delay delay;

    public UserController(UserService userService, DtoMapperService dtoMapperService, Delay delay) {
        this.userService = userService;
        this.dtoMapperService = dtoMapperService;
        this.delay = delay;
    }

    @GetMapping({"", "/"})
    public List<UserDto> all() {
        LOGGER.debug("Received request to list all users");
        this.delay.delay();
        List<User> users = this.userService.listAll();
        List<UserDto> userDtos = users.stream()
            .map(dtoMapperService::toUserDto)
            .toList();
        LOGGER.debug("Returning {} users", userDtos.size());
        return userDtos;
    }

    @GetMapping({"/{id}",})
    public ResponseEntity<UserDto> findById(@PathVariable Long id) {
        LOGGER.debug("Received request to find user with id={}", id);
        this.delay.delay();
        User user = this.userService.findWithId(id);
        if (user == null) {
            LOGGER.debug("User with id={} not found, returning 404", id);
            return ResponseEntity.notFound().build();
        }
        UserDto dto = this.dtoMapperService.toUserDto(user);
        LOGGER.debug("Found user with id={}: {}", id, user.name());
        return ResponseEntity.ok(dto);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        LOGGER.info("Received request to delete user with id={}", id);
        this.delay.delay();
        try {
            this.userService.delete(id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            LOGGER.error("Failed to delete user with id={}", id, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping(path = "/users", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<UserDto> createUser(@RequestBody CreateUserRequest request) {
        LOGGER.info("Received request to create user with name='{}', countryId={}, companyId={}", request.name(), request.countryId(), request.companyId());

        if (request.name() == null || request.name().trim().isEmpty()) {
            LOGGER.warn("Validation failed: name is null or empty");
            return ResponseEntity.badRequest().build();
        }

        if (request.countryId() == null || request.companyId() == null) {
            LOGGER.warn("Validation failed: countryId or companyId is null");
            return ResponseEntity.badRequest().build();
        }

        this.delay.delay();

        try {
            User createdUser = this.userService.create(request.name(), request.countryId(), request.companyId());
            UserDto dto = this.dtoMapperService.toUserDto(createdUser);
            LOGGER.info("Successfully created user with id={}, name='{}', countryId={}, companyId={}", createdUser.id(), createdUser.name(), createdUser.countryId(), createdUser.companyId());
            return ResponseEntity.status(HttpStatus.CREATED).body(dto);
        } catch (IllegalArgumentException e) {
            LOGGER.error("Validation error creating user: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            LOGGER.error("Failed to create user with name='{}', countryId={}, companyId={}", request.name(), request.countryId(), request.companyId(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @PutMapping(path = "/users/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<UserDto> updateUser(@PathVariable Long id, @RequestBody UpdateUserRequest request) {
        LOGGER.info("Received request to update user id={}", id);

        if (request.name() == null || request.name().trim().isEmpty()) {
            LOGGER.warn("Validation failed: name is null or empty");
            return ResponseEntity.badRequest().build();
        }

        if (request.countryId() == null || request.companyId() == null) {
            LOGGER.warn("Validation failed: countryId or companyId is null");
            return ResponseEntity.badRequest().build();
        }

        this.delay.delay();

        try {
            User updated = this.userService.update(id, request.name(), request.countryId(), request.companyId());
            UserDto dto = this.dtoMapperService.toUserDto(updated);
            LOGGER.info("Successfully updated user with id={}", id);
            return ResponseEntity.ok(dto);
        } catch (IllegalArgumentException e) {
            LOGGER.error("Validation error updating user id={}: {}", id, e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            LOGGER.error("Failed to update user id={}", id, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    public record CreateUserRequest(String name, Long countryId, Long companyId) {}

    public record UpdateUserRequest(String name, Long countryId, Long companyId) {}

}
