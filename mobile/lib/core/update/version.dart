// Re-export `pub_semver.Version` sebagai `core.Version` agar service
// lain tidak perlu import package eksternal. Memudahkan swap implementasi
// di kemudian hari (mis. parsing versi custom "1.2.0-beta.1").
export 'package:pub_semver/pub_semver.dart' show Version;