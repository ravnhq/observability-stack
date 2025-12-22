import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../common/services/prisma.service';
import { CreateUserDto } from '../dtos/requests/create-user.dto';
import { UpdateUserDto } from '../dtos/requests/update-user.dto';
import { UserDto } from '../dtos/responses/user.dto';
import { UserEntity } from '../entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectPinoLogger(UsersService.name)
    private readonly logger: PinoLogger,
  ) {}

  async create(createUserDto: CreateUserDto): Promise<UserDto> {
    this.logger.info('Creating user');
    const user = await this.prisma.user.create({
      data: createUserDto,
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    const entity = UserEntity.fromPrisma(user);
    this.logger.info(entity.toLogSafe(), 'User created');

    return entity.toResponseDto();
  }

  async findAll(filters?: { companyId?: string; countryId?: string }): Promise<UserDto[]> {
    const where: any = {};

    if (filters?.companyId) {
      where.companyId = filters.companyId;
    }

    if (filters?.countryId) {
      where.countryId = filters.countryId;
    }

    const users = await this.prisma.user.findMany({
      where,
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    this.logger.info({ count: users.length, filters }, 'Fetched users');

    return users.map(user => UserEntity.fromPrisma(user).toResponseDto());
  }

  async findOne(id: string): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Fetching user');
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    if (!user) {
      this.logger.info({ userId: id }, 'User not found');
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    const entity = UserEntity.fromPrisma(user);
    return entity.toResponseDto();
  }

  async findByEmail(email: string): Promise<UserDto> {
    this.logger.info('Finding user by email');
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    if (user) {
      const entity = UserEntity.fromPrisma(user);
      this.logger.info({ userId: user.id, displayName: entity.getDisplayName() }, 'User found by email');
      return entity.toResponseDto();
    } else {
      this.logger.info('User not found by email');
      return null as any;
    }
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Updating user');
    await this.findOne(id);

    const user = await this.prisma.user.update({
      where: { id },
      data: updateUserDto,
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    const entity = UserEntity.fromPrisma(user);
    this.logger.info(entity.toLogSafe(), 'User updated');

    return entity.toResponseDto();
  }

  async remove(id: string): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Removing user');
    await this.findOne(id);

    const user = await this.prisma.user.delete({
      where: { id },
      include: {
        country: true,
        company: {
          include: {
            country: true,
          },
        },
      },
    });

    const entity = UserEntity.fromPrisma(user);
    this.logger.info(entity.toLogSafe(), 'User removed');

    return entity.toResponseDto();
  }
}