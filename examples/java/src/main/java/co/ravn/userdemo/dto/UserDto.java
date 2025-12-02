package co.ravn.userdemo.dto;

public record UserDto(Long id, String name, CountryDto country, CompanyDto company) {
}
