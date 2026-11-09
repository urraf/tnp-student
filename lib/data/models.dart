import '../core/config.dart';
import '../core/utils.dart';

/// `/users/me`
class AppUser {
  AppUser(this.raw);
  final Json raw;

  String get id => idOf(raw);
  String get username => strOr(raw['username']);
  String get email => strOr(raw['email']);

  /// The linked student record id (string id or populated object).
  String get studentId {
    final s = raw['student'];
    if (s == null) return '';
    return idOf(s);
  }
}

class ResumeFile {
  ResumeFile(this.raw);
  final Json raw;

  String get uploadId => strOr(raw['_id'] ?? raw['id']);
  String get name => strOr(raw['name'], 'Resume');
  String get url => strOr(raw['url']);
  String? get ext => str(raw['ext']);
  dynamic get size => raw['size'];
  DateTime? get createdAt => date(raw['createdAt'] ?? raw['created_at']);
}

class Course {
  Course(this.raw);
  final Json raw;

  String get code => strOr(raw['courseCode']);
  String get title => strOr(raw['courseTitle']);
  String get type => strOr(raw['courseType']);
  int get credits => integer(raw['credits']) ?? 0;
  int get creditPoints => integer(raw['creditPoints']) ?? 0;
  String get grade => strOr(raw['gradeLetter']);
  double get gpa => credits == 0 ? 0 : creditPoints / credits;
}

/// `/students/me`
class Student {
  Student(this.raw);
  final Json raw;

  String get id => idOf(raw);
  String get name => strOr(raw['Name'], 'Student');
  String get rollNumber => strOr(raw['rollNumber']);
  String get email => strOr(raw['email']);
  String get personalEmail => strOr(raw['personal_email']);
  String get branch => strOr(raw['branch']);
  String get degree => strOr(raw['degree']);
  String get batch => strOr(raw['batch']);
  String get campus => strOr(raw['campus']);
  String get gender => strOr(raw['gender']);
  String get bloodGroup => strOr(raw['blood_group']);
  String get contactNumber => strOr(raw['contact_number']);
  String get altContactNumber => strOr(raw['alt_contact_number']);
  String get permAddress => strOr(raw['perm_address']);
  String get presentAddress => strOr(raw['present_address']);
  String get aadhar => strOr(raw['aadhar']);
  String get pan => strOr(raw['pan']);
  String get dob => strOr(raw['dob']);
  String get category => strOr(raw['category']);
  String? get photoUrl {
    final p = raw['photo'];
    if (p is Map) return str(p['url']);
    return str(p);
  }

  dynamic get cgpa => raw['cgpa'];
  dynamic get cgpa10th => raw['cgpa_10th'];
  dynamic get cgpa12th => raw['cgpa_12th'];
  dynamic get graduationGpa => raw['graduation_gpa'];
  dynamic get cgpaBeforeDrop => raw['cgpa_before_drop'];
  dynamic get backlogs => raw['backlogs'];
  dynamic get bans => raw['bans'];

  dynamic semGpa(int sem) => raw['sem${sem}_gpa'];

  bool get banStatus => boolean(raw['banStatus']);
  bool get isCgpaUpdated => boolean(raw['isCgpaUpdated']);
  bool get cgpaUpdateEnabled => boolean(raw['cgpaUpdateEnabled']);

  /// Mirrors the web logic for which batch's notices a student sees.
  String get placementBatch {
    if (raw['allowed_in_next_season'] == false) return batch;
    final b = int.tryParse(batch);
    return b == null ? batch : '${b + 1}';
  }

  int get totalSemesters => Catalog.degreesToSem[degree] ?? 8;

  /// True when the final semester GPA has been published.
  bool get lastSemGpaAvailable {
    final sems = Catalog.degreesToSem[degree];
    if (sems == null) return false;
    return str(semGpa(sems)) != null;
  }

  bool get isMasters => degree.isNotEmpty && degree[0].toUpperCase() == 'M';

  List<ResumeFile> get resumes => asJsonList(raw['resume']).map(ResumeFile.new).toList();

  Json get allSemGpa => asJson(raw['allSemGPA']);
  List<Course> get courses => asJsonList(allSemGpa['courseWiseData']).map(Course.new).toList();
  List<Json> get semesterWise => asJsonList(allSemGpa['semesterWiseData']);

  String get courseType => Catalog.courseTypeFor(degree, batch);
}

class Attachment {
  Attachment(this.raw);
  final Json raw;
  String get name => strOr(raw['name'], 'Attachment');
  String get url => strOr(raw['url']);
  String get ext {
    final e = str(raw['ext']);
    if (e != null) return e.replaceAll('.', '').toUpperCase();
    final u = url.toLowerCase();
    final dot = u.lastIndexOf('.');
    return dot == -1 ? 'FILE' : u.substring(dot + 1).toUpperCase();
  }

  dynamic get size => raw['size'];
  bool get isPdf => ext == 'PDF';
}

/// `/announcements`
class Announcement {
  Announcement(this.raw);
  final Json raw;

  String get id => idOf(raw);
  String get title => strOr(raw['title'], 'Untitled');
  String get company => strOr(raw['company']);
  String? get companyId => str(raw['company_id']) ?? (raw['company_id'] is Map ? idOf(raw['company_id']) : null);
  String? get eventId => str(raw['event_id']) ?? (raw['event_id'] is Map ? idOf(raw['event_id']) : null);
  String get type => strOr(raw['type'], 'General');
  String? get tag => str(raw['tag']);
  dynamic get content => raw['content'];
  String? get redirectUrl => str(raw['redirect_url']);
  DateTime? get publishedAt => date(raw['published_at'] ?? raw['createdAt']);
  List<String> get batches => strList(raw['batches']);
  List<String> get degrees => strList(raw['degrees']);
  List<Attachment> get attachments {
    final a = raw['attachment'];
    if (a is Map) return [Attachment(asJson(a))];
    return asJsonList(a).map(Attachment.new).toList();
  }

  bool get isCompanyEvent => type == 'CompanyEvent';

  late final String plainContent = RichText2Html.toPlain(content);
}

class CompanyInfo {
  CompanyInfo(this.raw);
  final Json raw;
  String get name => strOr(raw['name'] ?? raw['Name']);
  dynamic get info => raw['info'];
  String? get category => str(raw['company_category']);
  String? get turnover => str(raw['company_turnover']);
  int get eventCount => raw['events'] is List ? (raw['events'] as List).length : 0;
}

class AdditionalQuestion {
  AdditionalQuestion(this.raw);
  final Json raw;
  String get question => strOr(raw['ques']);

  /// One of: text, single, multi, file.
  String get type => strOr(raw['type'], 'text');
  List<String> get options => strList(raw['options']);
  String get hint => strOr(raw['expectedAns']);
}

/// `/company-events`
class CompanyEvent {
  CompanyEvent(this.raw);
  final Json raw;

  String get id => idOf(raw);
  String get companyName {
    final c = raw['company'];
    if (c is Map) return strOr(c['Name'] ?? c['name']);
    return strOr(c);
  }

  String get jobTitle => strOr(raw['jobtitle'], 'Opening');
  String get type => strOr(raw['type']);
  String get status => strOr(raw['status']);
  DateTime? get lastDate => date(raw['lastDate']);
  String get placeOfPosting => strOr(raw['placeOfPosting']);
  String get batch => strOr(raw['batch']);
  String get stipend => strOr(raw['stipend']);
  String? get stipendInfo => str(raw['stipend_info']);
  String get cgpa => strOr(raw['cgpa']);
  String get category => strOr(raw['category']).toUpperCase();
  String get backlogs => strOr(raw['backlogs']);
  String get coordinators => strOr(raw['apc']);
  String? get additionalInfo => str(raw['additional_info']);
  String? get formLink => str(raw['optional_redirect']);
  String get description => strOr(raw['description']);
  bool get optionalCriteria => raw['optional_criteria'] == true;
  List<Attachment> get attachments => asJsonList(raw['attachments']).map(Attachment.new).toList();

  bool get hasAdditionalQuestions => raw['is_additional_ques'] == true;
  List<AdditionalQuestion> get additionalQuestions =>
      asJsonList(raw['additional_ques']).map(AdditionalQuestion.new).toList();

  bool get registrationClosed {
    final d = lastDate;
    return d != null && d.isBefore(DateTime.now());
  }

  /// Same rule as the web table: status while open, "End" once closed.
  String get displayStatus {
    if (status.isEmpty) return '—';
    return registrationClosed ? 'Ended' : status;
  }

  bool get showsCriteria => Catalog.eventTypes.contains(type);

  /// {degree: [branches]}
  Map<String, List<String>> get branchesAllowed {
    final map = <String, List<String>>{};
    for (final b in asJsonList(raw['branchesAllowed'])) {
      final degree = strOr(b['degree'], 'Other');
      final branch = str(b['branch']);
      if (branch == null) continue;
      map.putIfAbsent(degree, () => []).add(branch);
    }
    return map;
  }
}

/// `/company-events/is_student_eligible/:id`
class Eligibility {
  Eligibility(this.raw);
  final Json raw;

  Json get _eligible => asJson(raw['eligible']);
  bool get eligible => _eligible['status'] == true;
  Json get conditions => asJson(_eligible['conditions']);

  bool get alreadyApplied => conditions['already_applied'] == true;
  bool get alreadyPlaced => conditions['already_placed'] == true;

  /// A truthy condition flag means that criterion *failed* (same JS
  /// truthiness check as the web: `conditions && !conditions[key]`).
  bool passes(String key) => conditions.isNotEmpty && !_truthy(conditions[key]);

  static bool _truthy(dynamic v) {
    if (v == null || v == false) return false;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    return true;
  }

  static const criteria = <(String, String)>[
    ('cgpa', 'CGPA'),
    ('cgpa_not_updated', 'CGPA updated'),
    ('batch', 'Batch'),
    ('percentage_10th', '10th percentage'),
    ('percentage_12th', '12th percentage'),
    ('branch', 'Branch'),
    ('degree', 'Degree'),
    ('backlogs', 'Backlogs'),
    ('ban', 'No active ban'),
    ('gender', 'Gender'),
    ('form_uploaded', 'Mandatory documents uploaded'),
  ];
}

/// `/students/my_applied`
class Application {
  Application(this.raw);
  final Json raw;
  String get id => idOf(raw);
  CompanyEvent? get event {
    final e = raw['company_event'];
    if (e is Map) return CompanyEvent(asJson(e));
    return null;
  }

  String get status => strOr(raw['status']);
  DateTime? get appliedAt => date(raw['createdAt']);
}

/// `/feedbacks`
class FeedbackItem {
  FeedbackItem(this.raw);
  final Json raw;
  String get id => idOf(raw);
  String get type => strOr(raw['feedback_type'], 'query');
  String get body => strOr(raw['feedback_data']);
  String get reply => strOr(raw['feedback_reply']);
  bool get resolved => raw['isResolved'] == true;
  DateTime? get createdAt => date(raw['createdAt']);
  DateTime? get resolvedAt => date(raw['resolved_date']);
  String get resolvedBy => strOr(raw['resolved_by']);
}

/// `/forms`
class FormDoc {
  FormDoc(this.raw);
  final Json raw;
  String get id => strOr(raw['_id'] ?? raw['id']);
  String get name => strOr(raw['name'], 'Form');
  bool get isBlocking => raw['is_blocking'] == true;
  String? get fileUrl => str(asJson(raw['file'])['url']);
}

/// `/form-uploads/me`
class FormUpload {
  FormUpload(this.raw);
  final Json raw;
  String get id => strOr(raw['_id'] ?? raw['id']);
  String get formId => strOr(asJson(raw['form'])['_id'] ?? asJson(raw['form'])['id']);
  String get formName => strOr(asJson(raw['form'])['name'], 'Unknown form');
  String get status => strOr(raw['status'], 'PENDING');
  String get message => strOr(raw['message']);
  String? get fileUrl => str(asJson(raw['file'])['url']);
  DateTime? get createdAt => date(raw['createdAt']);
}

/// `/nocs/student`
class Noc {
  Noc(this.raw);
  final Json raw;
  String get id => idOf(raw);
  String get company => strOr(raw['company']);
  String get address => strOr(raw['address']);
  String get city => strOr(raw['city']);
  String get state => strOr(raw['state']);
  String get pinCode => strOr(raw['pinCode']);
  String get start => strOr(raw['start'] ?? raw['startDate']);
  String get end => strOr(raw['end'] ?? raw['endDate']);
  String get source => strOr(raw['source']).replaceAll('_', ' ');
  String get message => strOr(raw['message']);
  String? get nocLink => str(raw['noc_link']);
  DateTime? get createdAt => date(raw['createdAt']);
  bool get accepted => raw['allowed'] == true;
  bool get rejected => raw['rejected'] == true;
  bool get pending => !accepted && !rejected;
  String get statusLabel => accepted
      ? 'Accepted'
      : rejected
      ? 'Rejected'
      : 'Pending';
}

class NoticeDetail {
  NoticeDetail({required this.notice, this.company, this.related = const []});
  final Announcement notice;
  final CompanyInfo? company;
  final List<Announcement> related;
}
