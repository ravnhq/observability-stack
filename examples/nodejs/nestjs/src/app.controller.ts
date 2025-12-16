import { Controller, Get, Header } from '@nestjs/common';
import { AppService } from './app.service';
import { MetricsService } from './common/services/metrics.service';
import { HealthResponseDto } from './common/dtos/responses/health.dto';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly metricsService: MetricsService,
  ) { }

  @Get()
  getHealth(): HealthResponseDto {
    return this.appService.getHealth();
  }

  @Get('metrics')
  @Header('Content-Type', 'application/openmetrics-text; version=1.0.0; charset=utf-8')
  async getMetrics(): Promise<string> {
    return this.metricsService.getMetrics();
  }
}
