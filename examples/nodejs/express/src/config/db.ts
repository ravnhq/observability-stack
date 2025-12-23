// src/config/db.ts
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

function getDatabaseUrl(): string {
	const url = process.env.DB_URL ?? process.env.DATABASE_URL;

	if (!url || url.trim().length === 0) {
		throw new Error(
			'Missing database connection string. Set `DB_URL` (preferred) or `DATABASE_URL`.'
		);
	}

	return url;
}

const pool = new Pool({ connectionString: getDatabaseUrl() });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

export { prisma };