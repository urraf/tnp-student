/// Static configuration shared across the app. Values mirror the web portal
/// (`runnable/src/constants.js`) so the app talks to the backend exactly the
/// same way the website does.
class AppConfig {
  AppConfig._();

  static const appName = 'TnP Student';
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.tnpnsut.in');

  static const companyLogoBase = 'https://tnp-company-logos.s3.ap-south-1.amazonaws.com';
  static const placementPolicyUrl = 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf';

  static String companyLogoUrl(String name) => '$companyLogoBase/${Uri.encodeComponent(name)}.png';

  static const noticePageSize = 12;
  static const jobsPageSize = 14;

  // ----------------------------------------------------------- Releases --
  // Updates are published as GitHub Releases. Each release must attach the APK
  // as [apkAssetName] and use a tag like `v1.2.0` matching pubspec `version`.
  static const githubRepo = 'urraf/tnp-student';
  static const apkAssetName = 'TnP-Student.apk';
  static const websiteUrl = 'https://tnp.nahraf.tech/';
  static const latestReleaseApi = 'https://api.github.com/repos/$githubRepo/releases/latest';
}

class Catalog {
  Catalog._();

  static const categories = ['GENERAL', 'EWS', 'OBC', 'SC', 'ST'];
  static const degreesToSem = <String, int>{
    'BTech': 8,
    'MTech': 4,
    'MBA': 4,
    'BBA': 6,
    'MSc': 4,
    'BDesign': 8,
    'MA': 4,
  };

  /// Event types for which eligibility criteria are shown.
  static const eventTypes = ['Internship', 'Internship+PPO', 'Internship+FTE', 'FTE', 'Placement'];

  static const feedbackTypes = {'query': 'Query', 'suggestion': 'Suggestion', 'complaint': 'Complaint'};

  static const dropRules = <String, ({int maxCredits, int maxSubjects})>{
    'BTech(Final year)': (maxCredits: 8, maxSubjects: 2),
    'BTech(Pre-Final Year)': (maxCredits: 4, maxSubjects: 1),
    'MTech': (maxCredits: 4, maxSubjects: 1),
    'BBA': (maxCredits: 4, maxSubjects: 1),
    'MBA': (maxCredits: 4, maxSubjects: 1),
    'MA': (maxCredits: 4, maxSubjects: 1),
    'MSc': (maxCredits: 4, maxSubjects: 1),
    'BDesign(Final year)': (maxCredits: 8, maxSubjects: 2),
    'BDesign(Pre-Final Year)': (maxCredits: 4, maxSubjects: 1),
  };

  static String findCourseYear(int batch) {
    final now = DateTime.now();
    final academicYear = now.month >= 6 ? now.year : now.year - 1;
    final yearsUntilGraduation = batch - academicYear;
    if (yearsUntilGraduation <= 1) return '(Final year)';
    if (yearsUntilGraduation == 2) return '(Pre-Final Year)';
    return '';
  }

  static String courseTypeFor(String degree, String batch) {
    final b = int.tryParse(batch) ?? 0;
    if (degree == 'BTech') return 'BTech${findCourseYear(b)}';
    if (degree == 'BDesign') return 'BDesign${findCourseYear(b)}';
    return degree;
  }
}
