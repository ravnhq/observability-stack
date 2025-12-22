import { Exclude, Expose, Type } from "class-transformer";
import { CountryDto } from "../../../countries/dtos/responses/country.dto";
import { CompanyDto } from "../../../companies/dtos/responses/company.dto";

@Exclude()
export class UserDto {
  @Expose()
  id: string

  @Expose()
  email: string

  @Expose()
  name: string

  @Expose()
  @Type(() => CountryDto)
  country: CountryDto

  @Expose()
  @Type(() => CompanyDto)
  company: CompanyDto

  @Expose()
  createdAt: Date

  @Expose()
  updatedAt: Date
}