import { Resolver, Query, Mutation, Args, ID, ResolveField, Parent } from '@nestjs/graphql';
import { UsersService } from '../services/users.service';
import { UserDto } from '../dtos/responses/user.dto';
import { UpdateUserInput } from '../types/inputs/update-user.input';
import { CompanyDto } from '../../companies/dtos/responses/company.dto';
import { CountryDto } from '../../countries/dtos/responses/country.dto';

@Resolver(() => UserDto)
export class UsersResolver {
  constructor(private readonly usersService: UsersService) {}

  @Query(() => [UserDto], { name: 'users' })
  async findAll(
    @Args('companyId', { type: () => ID, nullable: true }) companyId?: string,
    @Args('countryId', { type: () => ID, nullable: true }) countryId?: string,
  ): Promise<UserDto[]> {
    return this.usersService.findAll({ companyId, countryId });
  }

  @Query(() => UserDto, { name: 'user' })
  async findOne(@Args('id', { type: () => ID }) id: string): Promise<UserDto> {
    return this.usersService.findOne(id);
  }

  @Mutation(() => UserDto)
  async updateUser(
    @Args('id', { type: () => ID }) id: string,
    @Args('input') input: UpdateUserInput,
  ): Promise<UserDto> {
    return this.usersService.update(id, input);
  }

  @Mutation(() => Boolean)
  async deleteUser(@Args('id', { type: () => ID }) id: string): Promise<boolean> {
    await this.usersService.remove(id);
    return true;
  }

  @ResolveField(() => CompanyDto, { nullable: true })
  async company(@Parent() user: UserDto): Promise<CompanyDto | null> {
    return user.company || null;
  }

  @ResolveField(() => CountryDto, { nullable: true })
  async country(@Parent() user: UserDto): Promise<CountryDto | null> {
    return user.country || null;
  }
}
