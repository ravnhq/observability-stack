import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../common/services/prisma.service';
import { CreateCountryDto } from '../dtos/requests/create-country.dto';
import { UpdateCountryDto } from '../dtos/requests/update-country.dto';
import { CountryDto } from '../dtos/responses/country.dto';
import { CountryEntity } from '../entities/country.entity';

@Injectable()
export class CountriesService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(CountriesService.name)
    private readonly logger: PinoLogger,
  ) {}

  async create(createCountryDto: CreateCountryDto): Promise<CountryDto> {
    this.logger.info('Creating country');
    const country = await this.prisma.country.create({
      data: createCountryDto,
    });

    this.logger.info({ countryId: country.id }, 'Country created');

    const entity = CountryEntity.fromPrisma(country);
    return entity.toResponseDto();
  }

  async findAll(): Promise<CountryDto[]> {
    const countries = await this.prisma.country.findMany();

    this.logger.info({ count: countries.length }, 'Fetched countries');

    return countries.map(country => CountryEntity.fromPrisma(country).toResponseDto());
  }

  async findOne(id: string): Promise<CountryDto> {
    this.logger.info({ countryId: id }, 'Fetching country');
    const country = await this.prisma.country.findUnique({
      where: { id },
    });

    if (!country) {
      this.logger.info({ countryId: id }, 'Country not found');
      throw new NotFoundException(`Country with ID ${id} not found`);
    }

    const entity = CountryEntity.fromPrisma(country);
    return entity.toResponseDto();
  }

  async update(id: string, updateCountryDto: UpdateCountryDto): Promise<CountryDto> {
    this.logger.info({ countryId: id }, 'Updating country');
    await this.findOne(id);

    const country = await this.prisma.country.update({
      where: { id },
      data: updateCountryDto,
    });

    this.logger.info({ countryId: country.id }, 'Country updated');

    const entity = CountryEntity.fromPrisma(country);
    return entity.toResponseDto();
  }

  async remove(id: string): Promise<CountryDto> {
    this.logger.info({ countryId: id }, 'Removing country');
    await this.findOne(id);

    const country = await this.prisma.country.delete({
      where: { id },
    });

    this.logger.info({ countryId: country.id }, 'Country removed');

    const entity = CountryEntity.fromPrisma(country);
    return entity.toResponseDto();
  }
}
