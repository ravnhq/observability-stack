import { Company as PrismaCompany } from '@prisma/client';
import { BaseEntity } from '../../common/entities/base.entity';
import { CountryEntity } from '../../countries/entities/country.entity';
import { CompanyDto } from '../dtos/responses/company.dto';

type PrismaCompanyWithRelations = PrismaCompany & {
  country?: any;
};

export class CompanyEntity extends BaseEntity {
  name: string;
  countryId: string;

  // Optional: populated when relations are included
  country?: CountryEntity;

  constructor(
    id: string,
    name: string,
    countryId: string,
    createdAt: Date,
    updatedAt: Date,
    country?: CountryEntity,
  ) {
    super(id, createdAt, updatedAt);
    this.name = name;
    this.countryId = countryId;
    this.country = country;
  }

  /**
   * Factory method: Create entity from Prisma model
   */
  static fromPrisma(prisma: PrismaCompanyWithRelations): CompanyEntity {
    const country = prisma.country
      ? CountryEntity.fromPrisma(prisma.country)
      : undefined;

    return new CompanyEntity(
      prisma.id,
      prisma.name,
      prisma.countryId,
      prisma.createdAt,
      prisma.updatedAt,
      country,
    );
  }

  /**
   * Map entity to response DTO
   */
  toResponseDto(): CompanyDto {
    const dto = new CompanyDto();
    dto.id = this.id;
    dto.name = this.name;
    dto.createdAt = this.createdAt;
    dto.updatedAt = this.updatedAt;

    if (this.country) {
      dto.country = this.country.toResponseDto();
    }

    return dto;
  }

  /**
   * Business logic: Check if company has valid country
   */
  hasCountry(): boolean {
    return !!this.country;
  }

  /**
   * Business logic: Get full company name with country
   */
  getFullName(): string {
    return this.country
      ? `${this.name} (${this.country.name})`
      : this.name;
  }
}
