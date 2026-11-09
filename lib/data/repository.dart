import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/utils.dart';
import 'models.dart';

/// A file chosen by the user, ready for multipart upload.
class PickedUpload {
  PickedUpload({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  String get extension {
    final i = name.lastIndexOf('.');
    return i == -1 ? '' : name.substring(i + 1).toLowerCase();
  }

  MultipartFile toMultipart() => MultipartFile.fromBytes(bytes, filename: name);
}

/// Every endpoint used by the student web portal, in one place.
class TnpRepository {
  TnpRepository(this.api);
  final ApiClient api;

  Dio get _dio => api.dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Strapi query strings use bracket keys (`_where[0][x]`). Build them by
  /// hand so they reach the server exactly as the web app sends them.
  String _q(String path, List<(String, Object?)> params) {
    final parts = <String>[];
    for (final (k, v) in params) {
      if (v == null) continue;
      final s = v.toString();
      parts.add('$k=${Uri.encodeQueryComponent(s)}');
    }
    return parts.isEmpty ? path : '$path?${parts.join('&')}';
  }

  // ---------------------------------------------------------------- Auth --

  Future<String> login(String identifier, String password) => _guard(() async {
    final res = await _dio.post(
      '/auth/local/',
      data: {'identifier': identifier.trim(), 'password': password},
      options: ApiClient.noAuth,
    );
    final jwt = str(asJson(res.data)['jwt']);
    if (jwt == null) throw ApiException('Login failed. Please try again.');
    return jwt;
  });

  Future<AppUser> me() => _guard(() async {
    final res = await _dio.get('/users/me');
    return AppUser(asJson(res.data));
  });

  Future<Student> studentMe() => _guard(() async {
    final res = await _dio.get('/students/me');
    return Student(asJson(res.data));
  });

  Future<void> forgotPassword(String email) => _guard(() async {
    await _dio.post('/auth/forgot-password', data: {'email': email.trim().toLowerCase()}, options: ApiClient.noAuth);
  });

  Future<void> resetPassword({required String code, required String password, required String confirmation}) =>
      _guard(() async {
        await _dio.post(
          '/auth/reset-password',
          data: {'code': code.trim(), 'password': password, 'passwordConfirmation': confirmation},
          options: ApiClient.noAuth,
        );
      });

  // --------------------------------------------------------------- IMS ----

  /// Returns the captcha image (usually a `data:` URL). The server keeps the
  /// expected answer in a session cookie, which our cookie jar retains.
  Future<String> captcha() => _guard(() async {
    final res = await _dio.get('/ims/auth/captcha');
    final img = str(asJson(res.data)['captchaImage']);
    if (img == null) throw ApiException('Could not load captcha.');
    return img;
  });

  Json _successOrThrow(Response res) {
    final data = asJson(res.data);
    if (data['success'] != true) {
      throw ApiException(str(data['message']) ?? 'Request failed.');
    }
    return data;
  }

  Future<void> updateCgpa({required String password, required String captcha}) => _guard(() async {
    final res = await _dio.post('/students/cgpa-update', data: {'password': password, 'captcha': captcha});
    _successOrThrow(res);
  });

  Future<void> dropCourses(List<String> courseCodes) => _guard(() async {
    final res = await _dio.post('/students/drop', data: {'courses': courseCodes});
    _successOrThrow(res);
  });

  // ------------------------------------------------------------ Profile ---

  Future<void> updatePersonalDetails(Map<String, dynamic> body) => _guard(() async {
    await _dio.put('/students/updatePersonalDetails', data: body);
  });

  Future<List<ResumeFile>> resumes() => _guard(() async {
    final res = await _dio.get('/students/resumes');
    return asJsonList(asJson(res.data)['resumes']).map(ResumeFile.new).toList();
  });

  /// `POST /upload` — returns the uploaded file objects.
  Future<List<Json>> uploadFile(PickedUpload file, {void Function(double)? onProgress}) => _guard(() async {
    final form = FormData.fromMap({'files': file.toMultipart()});
    final res = await _dio.post(
      '/upload',
      data: form,
      onSendProgress: onProgress == null ? null : (sent, total) => total > 0 ? onProgress(sent / total) : null,
    );
    return asJsonList(res.data);
  });

  Future<void> uploadResume(PickedUpload file, int index, {void Function(double)? onProgress}) => _guard(() async {
    final uploaded = await uploadFile(file, onProgress: onProgress);
    if (uploaded.isEmpty) throw ApiException('Upload failed.');
    final uploadId = strOr(uploaded.first['_id'] ?? uploaded.first['id']);
    await _dio.put('/students/resume', data: {'uploadId': uploadId, 'index': index});
  });

  Future<void> deleteResume(String uploadId) => _guard(() async {
    await _dio.put('/students/resume/$uploadId');
  });

  // ------------------------------------------------------- Announcements --

  Future<List<Announcement>> announcements({
    required Student student,
    required int start,
    String type = 'All',
    String? tag,
    String? search,
  }) => _guard(() async {
    final q = (search ?? '').trim();
    final path = _q('/announcements', [
      ('_sort', 'createdAt:desc'),
      ('_where[batches_contains]', student.placementBatch),
      ('_where[degrees_contains]', student.degree),
      ('_start', start),
      ('_limit', AppConfig.noticePageSize),
      if (type != 'All') ('type', type),
      if (tag != null && tag.isNotEmpty) ('tag', tag),
      if (q.isNotEmpty) ...[
        ('_where[_or][0][title_contains]', q),
        ('_where[_or][1][content_contains]', q),
        ('_where[_or][2][company_contains]', q),
      ],
    ]);
    final res = await _dio.get(path);
    return asJsonList(res.data).map(Announcement.new).toList();
  });

  Future<List<String>> announcementTags(String type) => _guard(() async {
    final res = await _dio.get('/announcements/subtypes/${Uri.encodeComponent(type)}');
    final list = strList(res.data).toSet().toList()..sort();
    return list;
  });

  Future<NoticeDetail> noticeDetail(String id) => _guard(() async {
    final res = await _dio.get('/announcements/$id');
    final notice = Announcement(asJson(res.data));

    CompanyInfo? company;
    final companyId = notice.companyId;
    final relatedKey = notice.eventId ?? notice.id;
    final results = await Future.wait([
      if (companyId != null)
        _dio.get('/companies/$companyId').then<Object?>((r) => r).catchError((_) => null)
      else
        Future<Object?>.value(null),
      _dio
          .get(_q('/announcements', [('event_id', relatedKey), ('_sort', 'published_at:desc'), ('_limit', 10)]))
          .then<Object?>((r) => r)
          .catchError((_) => null),
    ]);
    final companyRes = results[0];
    if (companyRes is Response) company = CompanyInfo(asJson(companyRes.data));
    final relatedRes = results[1];
    final related = relatedRes is Response
        ? asJsonList(relatedRes.data).map(Announcement.new).where((a) => a.id != notice.id).toList()
        : <Announcement>[];
    return NoticeDetail(notice: notice, company: company, related: related);
  });

  // -------------------------------------------------------- Company events

  Future<List<CompanyEvent>> companyEvents({required Student student, required int start}) => _guard(() async {
    final path = _q('/company-events', [
      ('_sort', 'createdAt:desc'),
      ('batch', student.batch),
      ('_where[0][degrees_allowed_contains]', student.degree),
      ('campus', student.campus),
      ('_start', start),
      ('_limit', AppConfig.jobsPageSize),
    ]);
    final res = await _dio.get(path);
    return asJsonList(res.data).map(CompanyEvent.new).toList();
  });

  Future<CompanyEvent> companyEvent(String id) => _guard(() async {
    final res = await _dio.get('/company-events/$id');
    return CompanyEvent(asJson(res.data));
  });

  Future<Eligibility> eligibility(String eventId, String studentId) => _guard(() async {
    final res = await _dio.get(_q('/company-events/is_student_eligible/$eventId', [('studentID', studentId)]));
    return Eligibility(asJson(res.data));
  });

  Future<void> apply({
    required String eventId,
    required String studentId,
    required String resumeUrl,
    List<Json>? answers,
  }) => _guard(() async {
    await _dio.put(
      '/company-events/apply/$eventId',
      data: {'studentID': studentId, 'student_resume': resumeUrl, 'Additional_answers': answers},
    );
  });

  Future<String?> withdraw({required String eventId, required String studentId}) => _guard(() async {
    final res = await _dio.post('/registrations/$eventId', data: {'student_id': studentId});
    return ApiException.messageFromBody(res.data);
  });

  Future<List<Application>> myApplications() => _guard(() async {
    final res = await _dio.get('/students/my_applied/');
    return asJsonList(res.data).map(Application.new).toList();
  });

  // ------------------------------------------------------------ Feedback --

  Future<void> submitFeedback(Map<String, dynamic> body) => _guard(() async {
    await _dio.post('/feedbacks', data: body);
  });

  Future<List<FeedbackItem>> feedbacks(String studentId, {bool resolvedOnly = false}) => _guard(() async {
    final path = resolvedOnly
        ? _q('/feedbacks', [
            ('_where[0][isResolved]', 'true'),
            ('_where[1][student_id]', studentId),
            ('_sort', 'createdAt:desc'),
          ])
        : _q('/feedbacks', [('_where[0][student_id]', studentId), ('_sort', 'createdAt:desc')]);
    final res = await _dio.get(path);
    return asJsonList(res.data).map(FeedbackItem.new).toList();
  });

  // --------------------------------------------------------------- Forms --

  Future<List<FormDoc>> forms() => _guard(() async {
    final res = await _dio.get('/forms?is_active=true&_sort=createdAt:desc');
    return asJsonList(res.data).map(FormDoc.new).toList();
  });

  Future<List<FormUpload>> formUploads() => _guard(() async {
    final res = await _dio.get('/form-uploads/me?_sort=createdAt:desc');
    final list = asJsonList(res.data).map(FormUpload.new).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  });

  Future<void> uploadForm(String formId, PickedUpload file, {void Function(double)? onProgress}) => _guard(() async {
    final form = FormData.fromMap({
      'data': jsonEncode({'formId': formId}),
      'files.file': file.toMultipart(),
    });
    await _dio.post(
      '/form-uploads/upload',
      data: form,
      onSendProgress: onProgress == null ? null : (s, t) => t > 0 ? onProgress(s / t) : null,
    );
  });

  Future<void> deleteFormUpload(String uploadId) => _guard(() async {
    await _dio.delete('/form-uploads/$uploadId/self');
  });

  // ---------------------------------------------------------------- NOCs --

  Future<List<Noc>> nocs() => _guard(() async {
    final res = await _dio.get('/nocs/student?_sort=createdAt:desc');
    final list = asJsonList(asJson(res.data)['applications']).map(Noc.new).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  });

  Future<void> applyNoc(Map<String, String> data, PickedUpload proof, {void Function(double)? onProgress}) =>
      _guard(() async {
        final form = FormData.fromMap({'data': jsonEncode(data), 'files.noc': proof.toMultipart()});
        await _dio.post(
          '/nocs/apply',
          data: form,
          onSendProgress: onProgress == null ? null : (s, t) => t > 0 ? onProgress(s / t) : null,
        );
      });

  Future<void> deleteNocs(List<String> ids) => _guard(() async {
    await _dio.post('/nocs/bulkDelete', data: {'ids': ids});
  });

  // ---------------------------------------------------------------- Files --

  /// Downloads a remote file (used by the in-app PDF viewer).
  Future<Uint8List> download(String url, {void Function(double)? onProgress, CancelToken? cancel}) => _guard(() async {
    final dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(minutes: 2)),
    );
    final res = await dio.get<List<int>>(
      url,
      cancelToken: cancel,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress == null ? null : (r, t) => t > 0 ? onProgress(r / t) : null,
    );
    return Uint8List.fromList(res.data ?? const []);
  });
}
