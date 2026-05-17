import 'package:flutter_dotenv/flutter_dotenv.dart';

// Web-specific initialization
Future<void> initializeWeb() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Could not load .env file: $e');
  }
}

// Get Google Maps API key for web
String? get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'];
