import 'entities/auth_user.dart';

abstract class AuthSession {
  AuthUser? get currentUser;
}
