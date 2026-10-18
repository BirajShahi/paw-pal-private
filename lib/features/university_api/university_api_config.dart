/// Settings for the NIT3213 university API.
///
/// This API is separate from PawPal's Supabase project. Student ID and
/// first name are typed into the login form and are not stored here.
abstract final class UniversityApiConfig {
  static const baseUrl = 'https://nit3213apinew.onrender.com';

  /// Campus path used by POST /{classLocation}/auth.
  ///
  /// Change this if your class uses another location, for example
  /// `sydney`. The dashboard URL does not include this value.
  static const classLocation = 'footscray';

  /// POST /{classLocation}/auth
  static Uri authUri() {
    return Uri.parse(baseUrl).replace(pathSegments: [classLocation, 'auth']);
  }

  /// GET /dashboard/{keypass}
  ///
  /// [keypass] comes from a successful login response. It is encoded so
  /// unusual characters cannot break the URL.
  static Uri dashboardUri(String keypass) {
    return Uri.parse(baseUrl).replace(pathSegments: ['dashboard', keypass]);
  }
}
