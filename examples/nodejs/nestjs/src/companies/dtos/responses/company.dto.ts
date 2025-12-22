import { Exclude, Expose, Type } from 'class-transformer';
import { CountryDto } from '../../../countries/dtos/responses/country.dto';

@Exclude()
export class CompanyDto {
  @Expose()
  id: string;

  @Expose()
  name: string;

  @Expose()
  @Type(() => CountryDto)
  country: CountryDto;

  @Expose()
  createdAt: Date;

  @Expose()
  updatedAt: Date;
}
