import '../models/import_result.dart';

class ImportFormatsData {
  static ImportFormats get formats => ImportFormats.fromJson({
        'instructions': {
          'uber': {
            'name': 'Uber Driver (rides)',
            'steps': [
              'Open the Uber Driver app → Account → Wallet → See earnings activity',
              'Or visit driver.uber.com → Earnings → export/download trip data',
              'Export as CSV and import here',
            ],
            'expected_columns': [
              'Trip request time',
              'Trip distance',
              'Driver earnings or Tips',
            ],
            'note':
                'Uber ride exports usually include trip distance in miles. '
                'For Uber Eats deliveries, pick the Uber Eats option instead.',
          },
          'ubereats': {
            'name': 'Uber Eats',
            'steps': [
              'Open Uber Driver / Uber Eats delivery earnings',
              'Or export trip/delivery data from the Uber driver portal when available',
              'Export as CSV and import here (or paste into a spreadsheet first)',
            ],
            'expected_columns': [
              'Date or delivery time',
              'Distance (if present)',
              'Earnings or Tips',
              'Restaurant / store (optional)',
            ],
            'note':
                'Uber Eats columns often differ from UberX rides. Distance is sometimes missing — '
                'set a default miles per delivery, or use TrekTrack GPS while delivering. '
                'Postmates is part of Uber Eats; use this option for old Postmates-style CSVs too.',
          },
          'doordash': {
            'name': 'DoorDash Dasher',
            'steps': [
              'Open Dasher app → Earnings → View earnings by week',
              'Or request your data at privacy.doordash.com (Download My Data)',
              'Export earnings CSV and import here',
            ],
            'expected_columns': [
              'Date',
              'Total Pay or Tips',
              'Distance (if available)',
              'Store name (optional)',
            ],
            'note':
                'DoorDash exports often lack mileage. Set a default miles estimate per delivery, '
                'or rely on TrekTrack GPS for deductible miles and use the CSV mainly for pay.',
          },
          'lyft': {
            'name': 'Lyft Driver',
            'steps': [
              'Visit lyft.com/driver/dashboard → Earnings → download ride history',
              'Export CSV and import here',
            ],
            'expected_columns': ['Date', 'Distance', 'Earnings'],
            'note': 'Lyft ride history often includes distance; still verify totals for tax use.',
          },
          'instacart': {
            'name': 'Instacart Shopper',
            'steps': [
              'Open Instacart Shopper app → Earnings → batch history',
              'Export or copy earnings data as CSV when available',
            ],
            'expected_columns': ['Date', 'Distance (if any)', 'Earnings'],
            'note':
                'Batches are not clean “trip distance” logs. Prefer TrekTrack GPS for miles; '
                'use import for dates and pay when distance is missing (set default miles).',
          },
          'amazonflex': {
            'name': 'Amazon Flex',
            'steps': [
              'Open the Amazon Flex app → Earnings for block/pay history',
              'There is often no full trip-distance CSV — create a spreadsheet if needed',
              'Columns: Date, Miles (estimate or from your GPS), Pay/Tips, optional Notes (station/block)',
            ],
            'expected_columns': [
              'Date',
              'Miles (you may need to fill this)',
              'Pay or Tips',
              'Notes (station / block)',
            ],
            'note':
                'Flex is block-based, not rideshare trip distance. Best practice: run TrekTrack GPS '
                'during blocks. Use import only if you build a CSV with date + miles + pay.',
          },
          'gopuff': {
            'name': 'GoPuff',
            'steps': [
              'Open the GoPuff driver app → earnings / delivery history',
              'Export is limited — copy into a spreadsheet if needed',
              'Save as CSV with Date, Miles, Pay/Tips, Notes',
            ],
            'expected_columns': ['Date', 'Miles', 'Pay or Tips', 'Notes'],
            'note':
                'GoPuff rarely provides clean mileage exports. Use TrekTrack GPS on shift; '
                'import mainly for pay if you have a spreadsheet.',
          },
          'generic': {
            'name': 'Generic CSV',
            'steps': [
              'Use any CSV with Date, Miles/Distance, and Tips/Earnings columns',
              'Optional Notes column for store, block, or city',
            ],
            'expected_columns': ['date', 'miles', 'tips', 'notes (optional)'],
            'note':
                'Works for any platform (including Flex, GoPuff, or custom logs). '
                'If miles are missing, set default miles below or fill the column first.',
          },
        },
        'sample_csv': {
          'uber':
              'Trip request time,Trip distance,Driver earnings,Product type\n'
              '2026-07-01 14:30:00,5.2,18.50,UberX\n'
              '2026-07-02 09:15:00,3.8,12.25,UberX',
          'ubereats':
              'Date,Restaurant,Total Pay,Distance\n'
              '07/01/2026,Chipotle,12.40,3.1\n'
              '07/02/2026,Starbucks,8.75,1.9',
          'doordash':
              'Date,Store Name,Total Pay,Distance\n'
              '07/01/2026,Chipotle,14.50,2.1\n'
              '07/02/2026,McDonalds,9.75,1.8',
          'lyft':
              'Date,Distance,Earnings\n'
              '2026-07-01,4.5,16.20\n'
              '2026-07-02,2.8,11.00',
          'instacart':
              'Date,Batch,Earnings,Distance\n'
              '2026-07-01,Costco,42.00,8.5\n'
              '2026-07-02,Kroger,28.50,5.2',
          'amazonflex':
              'date,miles,tips,notes\n'
              '2026-07-01,38.0,92.50,Morning block · DLA3\n'
              '2026-07-02,41.2,98.00,Evening block · DLA3',
          'gopuff':
              'date,miles,tips,notes\n'
              '2026-07-01,22.0,65.00,Evening shift\n'
              '2026-07-02,18.5,54.25,Lunch shift',
          'generic':
              'date,miles,tips,notes\n'
              '2026-07-01,5.2,18.50,Airport run\n'
              '2026-07-02,3.8,12.25,Downtown',
        },
      });
}
