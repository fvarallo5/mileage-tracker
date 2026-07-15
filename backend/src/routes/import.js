import { Router } from 'express';
import db from '../db.js';
import { getImportFormats, parseTripCsv } from '../lib/csvImporter.js';

const router = Router();

router.get('/formats', (_req, res) => {
  res.json(getImportFormats());
});

router.post('/preview', (req, res) => {
  try {
    const { csv, platform = 'generic', default_miles = 0 } = req.body;
    if (!csv || typeof csv !== 'string') {
      return res.status(400).json({ error: 'csv text is required' });
    }

    const result = parseTripCsv(csv, {
      platform,
      defaultMiles: Number(default_miles) || 0,
    });

    res.json({
      dry_run: true,
      platform: result.platform,
      detected_columns: result.columns,
      preview: result.trips,
      errors: result.errors,
      total_parsed: result.trips.length,
    });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.post('/', (req, res) => {
  try {
    const { csv, platform = 'generic', default_miles = 0, skip_duplicates = true } = req.body;
    if (!csv || typeof csv !== 'string') {
      return res.status(400).json({ error: 'csv text is required' });
    }

    const result = parseTripCsv(csv, {
      platform,
      defaultMiles: Number(default_miles) || 0,
    });

    const insert = db.prepare(
      'INSERT INTO trips (date, miles, tips, notes, source) VALUES (?, ?, ?, ?, ?)'
    );

    const findDuplicate = db.prepare(
      `SELECT id FROM trips
       WHERE date = ? AND ABS(miles - ?) < 0.05 AND ABS(tips - ?) < 0.01 AND source = ?`
    );

    const imported = [];
    const skipped = [];

    const importMany = db.transaction((trips) => {
      for (const trip of trips) {
        if (skip_duplicates) {
          const dup = findDuplicate.get(trip.date, trip.miles, trip.tips, trip.source);
          if (dup) {
            skipped.push({ ...trip, reason: 'duplicate' });
            continue;
          }
        }

        const row = insert.run(trip.date, trip.miles, trip.tips, trip.notes, trip.source);
        imported.push(
          db.prepare('SELECT * FROM trips WHERE id = ?').get(row.lastInsertRowid)
        );
      }
    });

    importMany(result.trips);

    res.status(201).json({
      platform: result.platform,
      imported_count: imported.length,
      skipped_count: skipped.length,
      error_count: result.errors.length,
      imported,
      skipped,
      errors: result.errors,
    });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

export default router;