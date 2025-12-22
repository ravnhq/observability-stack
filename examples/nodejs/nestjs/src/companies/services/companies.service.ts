import { Injectable, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../common/services/prisma.service';
import { CreateCompanyDto } from '../dtos/requests/create-company.dto';
import { UpdateCompanyDto } from '../dtos/requests/update-company.dto';
import { CompanyDto } from '../dtos/responses/company.dto';

@Injectable()
export class CompaniesService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(CompaniesService.name)
    private readonly logger: PinoLogger,
  ) {}

  async create(createCompanyDto: CreateCompanyDto): Promise<CompanyDto> {
    this.logger.info('Creating company');
    const company = await this.prisma.company.create({
      data: createCompanyDto,
      include: {
        country: true,
      },
    });

    this.logger.info({ companyId: company.id }, 'Company created');

    return plainToInstance(CompanyDto, company);
  }

  async findAll(): Promise<CompanyDto[]> {
    const companies = await this.prisma.company.findMany({
      include: {
        country: true,
      },
    });

    this.logger.info({ count: companies.length }, 'Fetched companies');

    return plainToInstance(CompanyDto, companies);
  }

  async findOne(id: string): Promise<CompanyDto> {
    this.logger.info({ companyId: id }, 'Fetching company');
    const company = await this.prisma.company.findUnique({
      where: { id },
      include: {
        country: true,
      },
    });

    if (!company) {
      this.logger.info({ companyId: id }, 'Company not found');
      throw new NotFoundException(`Company with ID ${id} not found`);
    }

    return plainToInstance(CompanyDto, company);
  }

  async update(id: string, updateCompanyDto: UpdateCompanyDto): Promise<CompanyDto> {
    this.logger.info({ companyId: id }, 'Updating company');
    await this.findOne(id);

    const company = await this.prisma.company.update({
      where: { id },
      data: updateCompanyDto,
      include: {
        country: true,
      },
    });

    this.logger.info({ companyId: company.id }, 'Company updated');

    return plainToInstance(CompanyDto, company);
  }

  async remove(id: string): Promise<CompanyDto> {
    this.logger.info({ companyId: id }, 'Removing company');
    await this.findOne(id);

    const company = await this.prisma.company.delete({
      where: { id },
      include: {
        country: true,
      },
    });

    this.logger.info({ companyId: company.id }, 'Company removed');

    return plainToInstance(CompanyDto, company);
  }
}
