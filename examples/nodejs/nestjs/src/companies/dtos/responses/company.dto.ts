import { Exclude, Expose, Type } from 'class-transformer';
import { ObjectType, Field, ID } from '@nestjs/graphql';
import { CountryDto } from '../../../countries/dtos/responses/country.dto';

@ObjectType('Company')
@Exclude()
export class CompanyDto {
  @Field(() => ID)
  @Expose()
  id: string;

  @Field()
  @Expose()
  name: string;

  @Field(() => CountryDto, { nullable: true })
  @Expose()
  @Type(() => CountryDto)
  country: CountryDto;

  @Field()
  @Expose()
  createdAt: Date;

  @Field()
  @Expose()
  updatedAt: Date;
}
