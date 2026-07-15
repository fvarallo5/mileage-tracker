import { Router } from 'express';
import db from '../db.js';

const router = Router();

router.get('/', (req, res) => {
  const { start, end, limit } = req.query;
  let sql = 'SELECT * FROM trips';
  const params = [];

  if (start && end) {
    sql += ' WHERE date >= ? AND date <= ?';
    params.push(start, end);
  }

  sql += ' ORDER BY date DESC, id DESC';

  if (limit) {
    sql += ' LIMIT ?';
    params.push(Number(limit));
  }

  const trips = db.prepare(sql).all(...params);
  res.json(trips);
});

router.get('/:id', (req, res) => {
  const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found' });
  res.json(trip);
});

router.post('/', (req, res) => {
  const { date, miles, tips = 0, notes = '', source = 'manual' } = req.body;

  if (!date || miles == null) {
    return res.status(400).json({ error: 'date and miles are required' });
  }
  if (Number(miles) <= 0) {
    return res.status(400).json({ error: 'miles must be greater than 0' });
  }
  if (Number(tips) < 0) {
    return res.status(400).json({ error: 'tips cannot be negative' });
  }

  const result = db
    .prepare('INSERT INTO trips (date, miles, tips, notes, source) VALUES (?, ?, ?, ?, ?)')
    .run(date, Number(miles), Number(tips), notes, source);

  const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(result.lastInsertRowid);
  res.status(201).json(trip);
});

router.put('/:id', (req, res) => {
  const existing = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Trip not found' });

  const { date, miles, tips, notes } = req.body;
  const updated = {
    date: date ?? existing.date,
    miles: miles ?? existing.miles,
    tips: tips ?? existing.tips,
    notes: notes ?? existing.notes,
  };

  if (Number(updated.miles) <= 0) {
    return res.status(400).json({ error: 'miles must be greater than 0' });
  }
  if (Number(updated.tips) < 0) {
    return res.status(400).json({ error: 'tips cannot be negative' });
  }

  db.prepare('UPDATE trips SET date = ?, miles = ?, tips = ?, notes = ? WHERE id = ?').run(
    updated.date,
    Number(updated.miles),
    Number(updated.tips),
    updated.notes,
    req.params.id
  );

  const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(req.params.id);
  res.json(trip);
});

router.delete('/:id', (req, res) => {
  const result = db.prepare('DELETE FROM trips WHERE id = ?').run(req.params.id);
  if (result.changes === 0) return res.status(404).json({ error: 'Trip not found' });
  res.status(204).send();
});

export default router;