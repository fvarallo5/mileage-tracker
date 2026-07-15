import db from './db.js';

const existing = db.prepare('SELECT COUNT(*) as count FROM trips').get();
if (existing.count > 0) {
  console.log('Database already has trips, skipping seed.');
  process.exit(0);
}

const insert = db.prepare('INSERT INTO trips (date, miles, tips, notes) VALUES (?, ?, ?, ?)');

const seedTrips = [
  ['2026-06-02', 12.4, 28.5, 'Airport run'],
  ['2026-06-03', 8.2, 15.0, 'Downtown delivery'],
  ['2026-06-05', 22.1, 45.75, 'Long haul + tip'],
  ['2026-06-09', 5.6, 8.0, 'Quick errand'],
  ['2026-06-12', 18.3, 32.0, 'Suburbs'],
  ['2026-06-16', 14.0, 22.5, 'Office commute'],
  ['2026-06-20', 9.8, 18.25, 'Evening shift'],
  ['2026-06-25', 31.2, 62.0, 'Weekend gig'],
  ['2026-07-01', 11.5, 20.0, 'Morning route'],
  ['2026-07-03', 16.7, 35.5, 'Client pickup'],
  ['2026-07-05', 7.3, 12.0, 'Short trip'],
  ['2026-04-10', 25.0, 48.0, 'Q2 start'],
  ['2026-05-15', 19.4, 40.0, 'Mid-quarter'],
];

const insertMany = db.transaction((trips) => {
  for (const trip of trips) insert.run(...trip);
});

insertMany(seedTrips);
console.log(`Seeded ${seedTrips.length} sample trips.`);