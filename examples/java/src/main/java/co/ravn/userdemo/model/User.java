package co.ravn.userdemo.model;

import org.jspecify.annotations.Nullable;

import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("users")
public record User(
    @Nullable @Id Long id,
    String name,
    Long countryId,
    Long companyId
) {
}
