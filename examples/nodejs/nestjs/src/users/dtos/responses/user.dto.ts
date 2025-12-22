import { Exclude, Expose, Type } from "class-transformer";
import { ObjectType, Field, ID } from '@nestjs/graphql';
import { CountryDto } from "../../../countries/dtos/responses/country.dto";
import { CompanyDto } from "../../../companies/dtos/responses/company.dto";

@ObjectType('User')
@Exclude()
export class UserDto {
  @Field(() => ID)
  @Expose()
  id: string

  @Field()
  @Expose()
  email: string

  @Field()
  @Expose()
  name: string

  @Field(() => CountryDto, { nullable: true })
  @Expose()
  @Type(() => CountryDto)
  country: CountryDto

  @Field(() => CompanyDto, { nullable: true })
  @Expose()
  @Type(() => CompanyDto)
  company: CompanyDto

  @Field()
  @Expose()
  createdAt: Date

  @Field()
  @Expose()
  updatedAt: Date
}