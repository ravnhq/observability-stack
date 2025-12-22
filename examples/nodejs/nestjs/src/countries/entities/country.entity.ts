import { Country as PrismaCountry } from '@prisma/client';
import { BaseEntity } from '../../common/entities/base.entity';
import { CountryDto } from '../dtos/responses/country.dto';

export class CountryEntity extends BaseEntity {
  name: string;

  constructor(
    id: string,
    name: string,
    createdAt: Date,
    updatedAt: Date,
  ) {
    super(id, createdAt, updatedAt);
    this.name = name;
  }

  /**
   * Factory method: Create entity from Prisma model
   */
  static fromPrisma(prisma: PrismaCountry): CountryEntity {
    return new CountryEntity(
      prisma.id,
      prisma.name,
      prisma.createdAt,
      prisma.updatedAt,
    );
  }

  /**
   * Map entity to response DTO
   */
  toResponseDto(): CountryDto {
    const dto = new CountryDto();
    dto.id = this.id;
    dto.name = this.name;
    dto.createdAt = this.createdAt;
    dto.updatedAt = this.updatedAt;
    return dto;
  }

  /**
   * Business logic: Validate country name
   */
  isValidName(): boolean {
    return this.name.length >= 2 && this.name.length <= 100;
  }
}
