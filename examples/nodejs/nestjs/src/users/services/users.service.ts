import { Injectable, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { PrismaService } from '../../common/services/prisma.service';
import { CreateUserDto } from '../dtos/requests/create-user.dto';
import { UpdateUserDto } from '../dtos/requests/update-user.dto';
import { UserDto } from '../dtos/responses/user.dto';

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
    });

    this.logger.info({ userId: user.id }, 'User created');

    return plainToInstance(UserDto, user);
  }

  async findAll(): Promise<UserDto[]> {
    const users = await this.prisma.user.findMany();

    this.logger.info({ count: users.length }, 'Fetched users');

    return plainToInstance(UserDto, users);
  }

  async findOne(id: string): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Fetching user');
    const user = await this.prisma.user.findUnique({
      where: { id },
    });

    if (!user) {
      this.logger.info({ userId: id }, 'User not found');
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    return plainToInstance(UserDto, user);
  }

  async findByEmail(email: string): Promise<UserDto> {
    this.logger.info('Finding user by email');
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    if (user) {
      this.logger.info({ userId: user.id }, 'User found by email');
    } else {
      this.logger.info('User not found by email');
    }

    return plainToInstance(UserDto, user);
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Updating user');
    await this.findOne(id);

    const user = await this.prisma.user.update({
      where: { id },
      data: updateUserDto,
    });

    this.logger.info({ userId: user.id }, 'User updated');

    return plainToInstance(UserDto, user);
  }

  async remove(id: string): Promise<UserDto> {
    this.logger.info({ userId: id }, 'Removing user');
    await this.findOne(id);

    const user = await this.prisma.user.delete({
      where: { id },
    });

    this.logger.info({ userId: user.id }, 'User removed');

    return plainToInstance(UserDto, user);
  }
}