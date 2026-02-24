import 'package:flutter_dotenv/flutter_dotenv.dart';

class JwtConfig {
  static String get jwtSecret => dotenv.env['JWT_SECRET'] ?? '';
}
