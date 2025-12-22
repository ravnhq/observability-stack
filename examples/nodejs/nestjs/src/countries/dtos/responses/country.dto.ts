import { Exclude, Expose } from 'class-transformer';
import { ObjectType, Field, ID } from '@nestjs/graphql';

@ObjectType('Country')
@Exclude()
export class CountryDto {
  @Field(() => ID)
  @Expose()
  id: string;

  @Field()
  @Expose()
  name: string;

  @Field()
  @Expose()
  createdAt: Date;

  @Field()
  @Expose()
  updatedAt: Date;
}
