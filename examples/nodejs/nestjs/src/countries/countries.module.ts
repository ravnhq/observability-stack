import { Module } from '@nestjs/common';
import { CountriesController } from './controllers/countries.controller';
import { CountriesService } from './services/countries.service';
import { CountriesResolver } from './resolvers/countries.resolver';

@Module({
  controllers: [CountriesController],
  providers: [CountriesService, CountriesResolver],
  exports: [CountriesService],
})
export class CountriesModule { }
