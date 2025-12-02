package co.ravn.userdemo.repository;

import co.ravn.userdemo.model.User;

import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.ListCrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface UserRepository extends ListCrudRepository<User, Long> {

    @Query("SELECT * FROM users WHERE company_id = :companyId")
    List<User> findByCompanyId(@Param("companyId") Long companyId);
}
