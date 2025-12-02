package co.ravn.userdemo.repository;

import co.ravn.userdemo.model.Country;
import org.springframework.data.repository.ListCrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CountryRepository extends ListCrudRepository<Country, Long> {
}
