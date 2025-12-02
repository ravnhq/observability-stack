package co.ravn.userdemo.repository;

import co.ravn.userdemo.model.Company;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.ListCrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CompanyRepository extends ListCrudRepository<Company, Long> {

    @Query("SELECT * FROM companies WHERE country_id = :countryId")
    List<Company> findByCountryId(@Param("countryId") Long countryId);
}
