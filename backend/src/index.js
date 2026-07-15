import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import tripsRouter from './routes/trips.js';
import importRouter from './routes/import.js';
import reportsRouter from './routes/reports.js';
import settingsRouter from './routes/settings.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const isProd = process.env.NODE_ENV === 'production';
const PORT = process.env.PORT || 3001;

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : null;

const app = express();

app.use(
  cors({
    origin: allowedOrigins
      ? (origin, cb) => {
          if (!origin || allowedOrigins.includes(origin)) cb(null, true);
          else cb(new Error('Not allowed by CORS'));
        }
      : true,
  })
);
app.use(express.json());

app.use(express.static(path.join(__dirname, '..', 'public')));

app.get('/privacy', (_req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'privacy.html'));
});

app.get('/', (_req, res) => {
  res.json({
    name: 'Mileage Tracker API',
    version: '1.0.0',
    environment: isProd ? 'production' : 'development',
    docs: '/api',
    privacy: '/privacy',
    health: '/api/health',
  });
});

app.get('/api', (_req, res) => {
  res.json({
    message: 'Mileage Tracker API — use specific endpoints below',
    endpoints: {
      health: 'GET /api/health',
      trips: 'GET|POST /api/trips',
      import: 'POST /api/trips/import',
      import_preview: 'POST /api/trips/import/preview',
      import_formats: 'GET /api/trips/import/formats',
      trip: 'GET|PUT|DELETE /api/trips/:id',
      report_summary: 'GET /api/reports/summary',
      reports: 'GET /api/reports/:period (weekly|monthly|annual)',
      settings: 'GET /api/settings',
      mileage_rate: 'PUT /api/settings/mileage-rate',
    },
  });
});

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/trips/import', importRouter);
app.use('/api/trips', tripsRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/settings', settingsRouter);

app.listen(PORT, () => {
  console.log(`Mileage Tracker API running on port ${PORT} (${isProd ? 'production' : 'development'})`);
});