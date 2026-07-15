import { Router } from 'express';
import db from '../db.js';

const router = Router();

router.get('/', (req, res) => {
  const rows = db.prepare('SELECT key, value FROM settings').all();
  const settings = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  res.json(settings);
});

router.put('/mileage-rate', (req, res) => {
  const { rate } = req.body;
  if (rate == null || Number(rate) <= 0) {
    return res.status(400).json({ error: 'rate must be a positive number' });
  }

  db.prepare(
    'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value'
  ).run('mileage_rate', String(rate));

  res.json({ mileage_rate: Number(rate) });
});

export default router;