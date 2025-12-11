import { Injectable } from '@nestjs/common';
import { HealthResponseDto } from './common/dtos/responses/health.dto';

@Injectable()
export class AppService {
  getHealth(): HealthResponseDto {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    }
  }
}
