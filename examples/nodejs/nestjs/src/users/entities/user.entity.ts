import { User as PrismaUser } from '@prisma/client';
import { BaseEntity } from '../../common/entities/base.entity';
import { CountryEntity } from '../../countries/entities/country.entity';
import { CompanyEntity } from '../../companies/entities/company.entity';
import { UserDto } from '../dtos/responses/user.dto';

type PrismaUserWithRelations = PrismaUser & {
  country?: any;
  company?: any;
};

export class UserEntity extends BaseEntity {
  email: string;
  name: string;
  password: string;
  countryId: string;
  companyId: string;

  // Optional: populated when relations are included
  country?: CountryEntity;
  company?: CompanyEntity;

  constructor(
    id: string,
    email: string,
    name: string,
    password: string,
    countryId: string,
    companyId: string,
    createdAt: Date,
    updatedAt: Date,
    country?: CountryEntity,
    company?: CompanyEntity,
  ) {
    super(id, createdAt, updatedAt);
    this.email = email;
    this.name = name;
    this.password = password;
    this.countryId = countryId;
    this.companyId = companyId;
    this.country = country;
    this.company = company;
  }

  /**
   * Factory method: Create entity from Prisma model
   */
  static fromPrisma(prisma: PrismaUserWithRelations): UserEntity {
    const country = prisma.country
      ? CountryEntity.fromPrisma(prisma.country)
      : undefined;

    const company = prisma.company
      ? CompanyEntity.fromPrisma(prisma.company)
      : undefined;

    return new UserEntity(
      prisma.id,
      prisma.email,
      prisma.name,
      prisma.password,
      prisma.countryId,
      prisma.companyId,
      prisma.createdAt,
      prisma.updatedAt,
      country,
      company,
    );
  }

  /**
   * Map entity to response DTO (excludes password)
   */
  toResponseDto(): UserDto {
    const dto = new UserDto();
    dto.id = this.id;
    dto.email = this.email;
    dto.name = this.name;
    dto.createdAt = this.createdAt;
    dto.updatedAt = this.updatedAt;

    if (this.country) {
      dto.country = this.country.toResponseDto();
    }

    if (this.company) {
      dto.company = this.company.toResponseDto();
    }

    return dto;
  }

  /**
   * Business logic: Check if email is from company domain
   */
  hasCompanyEmail(): boolean {
    if (!this.company) return false;
    const domain = this.email.split('@')[1];
    const companyDomain = this.company.name.toLowerCase().replace(/\s+/g, '') + '.com';
    return domain === companyDomain;
  }

  /**
   * Business logic: Check if password is strong
   */
  hasStrongPassword(): boolean {
    return (
      this.password.length >= 8 &&
      /[A-Z]/.test(this.password) &&
      /[a-z]/.test(this.password) &&
      /[0-9]/.test(this.password)
    );
  }

  /**
   * Business logic: Get user display name with company
   */
  getDisplayName(): string {
    return this.company ? `${this.name} @ ${this.company.name}` : this.name;
  }

  /**
   * Domain logic: Sanitize user for logging (no password)
   */
  toLogSafe(): Pick<UserEntity, 'id' | 'email' | 'name'> {
    return {
      id: this.id,
      email: this.email,
      name: this.name,
    };
  }
}
