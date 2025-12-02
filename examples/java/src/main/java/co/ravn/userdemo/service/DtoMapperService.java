package co.ravn.userdemo.service;

import co.ravn.userdemo.dto.CompanyDto;
import co.ravn.userdemo.dto.CountryDto;
import co.ravn.userdemo.dto.UserDto;
import co.ravn.userdemo.model.Company;
import co.ravn.userdemo.model.Country;
import co.ravn.userdemo.model.User;

import org.springframework.stereotype.Service;

@Service
public class DtoMapperService {
    private final CountryService countryService;
    private final CompanyService companyService;

    public DtoMapperService(CountryService countryService, CompanyService companyService) {
        this.countryService = countryService;
        this.companyService = companyService;
    }

    public CountryDto toCountryDto(Country country) {
        return new CountryDto(country.id(), country.name());
    }

    public CompanyDto toCompanyDto(Company company) {
        Country country = this.countryService.findById(company.countryId());
        CountryDto countryDto = toCountryDto(country);
        return new CompanyDto(company.id(), company.name(), countryDto);
    }

    public UserDto toUserDto(User user) {
        Country country = this.countryService.findById(user.countryId());
        CountryDto countryDto = toCountryDto(country);

        Company company = this.companyService.findById(user.companyId());
        CompanyDto companyDto = toCompanyDto(company);

        return new UserDto(user.id(), user.name(), countryDto, companyDto);
    }
}
