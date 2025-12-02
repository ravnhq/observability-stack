package co.ravn.userdemo.model;

import org.jspecify.annotations.Nullable;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("companies")
public record Company(
    @Nullable @Id Long id,
    String name,
    Long countryId
) {
}
