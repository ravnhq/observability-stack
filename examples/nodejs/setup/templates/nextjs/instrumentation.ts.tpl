export async function register() {
  const runtime = process.env.NEXT_RUNTIME || 'nodejs';
  console.log('[otel] instrumentation register invoked for runtime:', runtime);

  if (runtime !== 'nodejs') {
    console.log('[otel] skipping instrumentation for runtime:', runtime);
    return;
  }

  try {
    const { startNodeTelemetry } = await import('./otel');
    await startNodeTelemetry();
  } catch (error) {
    console.error('[otel] Failed to start node telemetry:', error);
  }
}
