import { NextResponse } from 'next/server';
import { getMetrics, metricsContentType } from '@/lib/metrics';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function GET() {
	const body = await getMetrics();
	return new NextResponse(body, {
		status: 200,
		headers: {
			'Content-Type': metricsContentType,
		},
	});
}