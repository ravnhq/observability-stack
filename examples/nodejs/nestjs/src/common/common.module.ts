import { Global, Module } from '@nestjs/common';
import { PrismaService } from './services/prisma.service';
import { MetricsService } from './services/metrics.service';

@Global()
@Module({
  providers: [PrismaService, MetricsService],
  exports: [PrismaService, MetricsService],
})
export class CommonModule { }
