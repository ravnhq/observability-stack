import { InputType, Field, ID } from '@nestjs/graphql';
import { IsEmail, IsOptional, IsString, IsUUID } from 'class-validator';

@InputType()
export class UpdateUserInput {
  @Field({ nullable: true })
  @IsEmail()
  @IsOptional()
  email?: string;

  @Field({ nullable: true })
  @IsString()
  @IsOptional()
  name?: string;

  @Field({ nullable: true })
  @IsString()
  @IsOptional()
  password?: string;

  @Field(() => ID, { nullable: true })
  @IsUUID()
  @IsOptional()
  countryId?: string;

  @Field(() => ID, { nullable: true })
  @IsUUID()
  @IsOptional()
  companyId?: string;
}
