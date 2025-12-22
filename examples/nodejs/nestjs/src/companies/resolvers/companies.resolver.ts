import { Resolver, Query, Mutation, Args, ID, ResolveField, Parent } from '@nestjs/graphql';
import { CompaniesService } from '../services/companies.service';
import { CompanyDto } from '../dtos/responses/company.dto';
import { UpdateCompanyInput } from '../types/inputs/update-company.input';
import { CountryDto } from '../../countries/dtos/responses/country.dto';

@Resolver(() => CompanyDto)
export class CompaniesResolver {
  constructor(private readonly companiesService: CompaniesService) {}

  @Query(() => [CompanyDto], { name: 'companies' })
  async findAll(): Promise<CompanyDto[]> {
    return this.companiesService.findAll();
  }

  @Query(() => CompanyDto, { name: 'company' })
  async findOne(@Args('id', { type: () => ID }) id: string): Promise<CompanyDto> {
    return this.companiesService.findOne(id);
  }

  @Mutation(() => CompanyDto)
  async updateCompany(
    @Args('id', { type: () => ID }) id: string,
    @Args('input') input: UpdateCompanyInput,
  ): Promise<CompanyDto> {
    return this.companiesService.update(id, input);
  }

  @Mutation(() => Boolean)
  async deleteCompany(@Args('id', { type: () => ID }) id: string): Promise<boolean> {
    await this.companiesService.remove(id);
    return true;
  }

  @ResolveField(() => CountryDto, { nullable: true })
  async country(@Parent() company: CompanyDto): Promise<CountryDto | null> {
    return company.country || null;
  }
}
