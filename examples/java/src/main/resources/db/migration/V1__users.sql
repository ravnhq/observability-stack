-- Countries table (no dependencies)
CREATE TABLE countries
(
    id   BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- Companies table (depends on countries)
CREATE TABLE companies
(
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    country_id BIGINT NOT NULL,
    CONSTRAINT fk_companies_country
        FOREIGN KEY (country_id)
        REFERENCES countries(id)
        ON DELETE CASCADE
);

-- Users table (depends on both countries and companies)
CREATE TABLE users
(
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    country_id BIGINT NOT NULL,
    company_id BIGINT NOT NULL,
    CONSTRAINT fk_users_country
        FOREIGN KEY (country_id)
        REFERENCES countries(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_users_company
        FOREIGN KEY (company_id)
        REFERENCES companies(id)
        ON DELETE CASCADE
);

-- Performance indexes for foreign key lookups
CREATE INDEX idx_companies_country_id ON companies(country_id);
CREATE INDEX idx_users_country_id ON users(country_id);
CREATE INDEX idx_users_company_id ON users(company_id);
