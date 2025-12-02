package co.ravn.userdemo.model;

import org.jspecify.annotations.Nullable;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Table;

@Table("countries")
public record Country(@Nullable @Id Long id, String name) {
}
