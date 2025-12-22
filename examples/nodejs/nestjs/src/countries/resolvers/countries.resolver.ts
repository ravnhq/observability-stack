import { Resolver, Query, Mutation, Args, ID } from '@nestjs/graphql';
import { CountriesService } from '../services/countries.service';
import { CountryDto } from '../dtos/responses/country.dto';
import { UpdateCountryInput } from '../types/inputs/update-country.input';

@Resolver(() => CountryDto)
export class CountriesResolver {
  constructor(private readonly countriesService: CountriesService) {}

  @Query(() => [CountryDto], { name: 'countries' })
  async findAll(): Promise<CountryDto[]> {
    return this.countriesService.findAll();
  }

  @Query(() => CountryDto, { name: 'country' })
  async findOne(@Args('id', { type: () => ID }) id: string): Promise<CountryDto> {
    return this.countriesService.findOne(id);
  }

  @Mutation(() => CountryDto)
  async updateCountry(
    @Args('id', { type: () => ID }) id: string,
    @Args('input') input: UpdateCountryInput,
  ): Promise<CountryDto> {
    return this.countriesService.update(id, input);
  }

  @Mutation(() => Boolean)
  async deleteCountry(@Args('id', { type: () => ID }) id: string): Promise<boolean> {
    await this.countriesService.remove(id);
    return true;
  }
}
