import '../models/import_result.dart';

class ImportFormatsData {
  static ImportFormats get formats => ImportFormats.fromJson({
        'instructions': {
          'uber': {
            'name': 'Uber Driver',
            'steps': [
              'Open the Uber Driver app → Account → Wallet → See earnings activity',
              'Or visit driver.uber.com → Earnings → export/download trip data',
              'Export as CSV and import here',
            ],
            'expected_columns': ['Trip request time', 'Trip distance', 'Driver earnings or Tips'],
            'note': 'Uber exports usually include trip distance in miles.',
          },
          'doordash': {
            'name': 'DoorDash Dasher',
            'steps': [
              'Open Dasher app → Earnings → View earnings by week',
              'Or request your data at privacy.doordash.com (Download My Data)',
              'Export earnings CSV and import here',
            ],
            'expected_columns': ['Date', 'Total Pay or Tips', 'Distance (if available)'],
            'note': 'DoorDash exports often lack mileage — set a default miles estimate per delivery.',
          },
          'lyft': {
            'name': 'Lyft Driver',
            'steps': [
              'Visit lyft.com/driver/dashboard → Earnings → download ride history',
              'Export CSV and import here',
            ],
            'expected_columns': ['Date', 'Distance', 'Earnings'],
          },
          'instacart': {
            'name': 'Instacart Shopper',
            'steps': [
              'Open Instacart Shopper app → Earnings → batch history',
              'Export or copy earnings data as CSV',
            ],
            'expected_columns': ['Date', 'Distance', 'Earnings'],
          },
          'generic': {
            'name': 'Generic CSV',
            'steps': ['Use any CSV with Date, Miles/Distance, and Tips/Earnings columns'],
            'expected_columns': ['date', 'miles', 'tips', 'notes (optional)'],
          },
        },
        'sample_csv': {
          'uber':
              'Trip request time,Trip distance,Driver earnings,Product type\n2026-07-01 14:30:00,5.2,18.50,UberX\n2026-07-02 09:15:00,3.8,12.25,UberX',
          'doordash':
              'Date,Store Name,Total Pay,Distance\n07/01/2026,Chipotle,14.50,2.1\n07/02/2026,McDonalds,9.75,1.8',
          'generic':
              'date,miles,tips,notes\n2026-07-01,5.2,18.50,Airport run\n2026-07-02,3.8,12.25,Downtown',
        },
      });
}