import { IsOptional, IsString } from 'class-validator';

export class UpdateCountryDto {
  @IsString()
  @IsOptional()
  name?: string;
}
