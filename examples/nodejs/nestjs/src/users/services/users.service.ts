import { Injectable, NotFoundException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { PrismaService } from '../../common/services/prisma.service';
import { CreateUserDto } from '../dtos/requests/create-user.dto';
import { UpdateUserDto } from '../dtos/requests/update-user.dto';
import { UserDto } from '../dtos/responses/user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) { }

  async create(createUserDto: CreateUserDto): Promise<UserDto> {
    const user = await this.prisma.user.create({
      data: createUserDto,
    });

    return plainToInstance(UserDto, user)
  }

  async findAll(): Promise<UserDto[]> {
    const users = await this.prisma.user.findMany();

    return plainToInstance(UserDto, users)
  }

  async findOne(id: string): Promise<UserDto> {
    const user = await this.prisma.user.findUnique({
      where: { id },
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    return plainToInstance(UserDto, user);
  }

  async findByEmail(email: string): Promise<UserDto> {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    return plainToInstance(UserDto, user);
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<UserDto> {
    await this.findOne(id);

    const user = await this.prisma.user.update({
      where: { id },
      data: updateUserDto,
    });

    return plainToInstance(UserDto, user);
  }

  async remove(id: string): Promise<UserDto> {
    await this.findOne(id);

    const user = await this.prisma.user.delete({
      where: { id },
    });

    return plainToInstance(UserDto, user);
  }
}