import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, '..', 'data', 'mileage.db');

import fs from 'fs';
fs.mkdirSync(path.dirname(dbPath), { recursive: true });

const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS trips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    miles REAL NOT NULL CHECK (miles > 0),
    tips REAL NOT NULL DEFAULT 0 CHECK (tips >= 0),
    notes TEXT,
    source TEXT NOT NULL DEFAULT 'manual',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_trips_date ON trips(date);
`);

const tripColumns = db.prepare('PRAGMA table_info(trips)').all();
if (!tripColumns.some((c) => c.name === 'source')) {
  db.exec(`ALTER TABLE trips ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'`);
}

const defaultRate = db.prepare('SELECT value FROM settings WHERE key = ?').get('mileage_rate');
if (!defaultRate) {
  db.prepare('INSERT INTO settings (key, value) VALUES (?, ?)').run('mileage_rate', '0.70');
}

export default db;