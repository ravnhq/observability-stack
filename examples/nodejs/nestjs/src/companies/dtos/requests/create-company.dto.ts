import { IsNotEmpty, IsString, IsUUID } from 'class-validator';

export class CreateCompanyDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsUUID()
  @IsNotEmpty()
  countryId: string;
}
