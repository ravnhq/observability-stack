import { Module } from '@nestjs/common';
import { UsersController } from './controllers/users.controller';
import { UsersService } from './services/users.service';
import { UsersResolver } from './resolvers/users.resolver';
import { CompaniesModule } from '../companies/companies.module';
import { CountriesModule } from '../countries/countries.module';

@Module({
  imports: [CompaniesModule, CountriesModule],
  controllers: [UsersController],
  providers: [UsersService, UsersResolver],
  exports: [UsersService],
})
export class UsersModule { }
