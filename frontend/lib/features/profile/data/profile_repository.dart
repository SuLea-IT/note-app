import '../../auth/domain/auth_session.dart';
import '../domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> fetchProfile();

  Future<UserProfile> updateProfile(UserProfileUpdate update);
}

abstract class ProfileSessionRepository extends ProfileRepository {
  ProfileSessionRepository(this.session);

  final AuthSession session;
}
