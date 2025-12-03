import { NextResponse } from 'next/server';
import { logger } from '@/lib/logger';

export async function GET() {
  logger.info('Test endpoint called - checking telemetry');
  logger.info({ test: 'data', timestamp: new Date().toISOString() }, 'Test log with structured data');
  
  return NextResponse.json({ 
    status: 'ok', 
    message: 'Test endpoint - check Grafana for logs and traces',
    timestamp: new Date().toISOString()
  });
}
