import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { CountriesService } from '../services/countries.service';
import { CreateCountryDto } from '../dtos/requests/create-country.dto';
import { UpdateCountryDto } from '../dtos/requests/update-country.dto';
import { CountryDto } from '../dtos/responses/country.dto';

@Controller('countries')
export class CountriesController {
  constructor(private readonly countriesService: CountriesService) { }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() createCountryDto: CreateCountryDto): Promise<CountryDto> {
    return this.countriesService.create(createCountryDto);
  }

  @Get()
  findAll(): Promise<CountryDto[]> {
    return this.countriesService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string): Promise<CountryDto> {
    return this.countriesService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateCountryDto: UpdateCountryDto): Promise<CountryDto> {
    return this.countriesService.update(id, updateCountryDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('id') id: string): Promise<CountryDto> {
    return this.countriesService.remove(id);
  }
}
