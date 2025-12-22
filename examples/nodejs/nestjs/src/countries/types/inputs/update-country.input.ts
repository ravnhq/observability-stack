import { InputType, Field } from '@nestjs/graphql';
import { IsOptional, IsString } from 'class-validator';

@InputType()
export class UpdateCountryInput {
  @Field({ nullable: true })
  @IsString()
  @IsOptional()
  name?: string;
}
