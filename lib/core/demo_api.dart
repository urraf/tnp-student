import 'package:dio/dio.dart';

/// Offline demo backend, enabled with `--dart-define=DEMO=true`.
/// Lets you preview every screen without a real TnP account.
/// It is never active in normal builds.
class DemoApiInterceptor extends Interceptor {
  static const enabled = bool.fromEnvironment('DEMO');

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final path = Uri.parse(options.path).path;
    final q = Uri.parse(options.path).queryParameters;
    final data = _route(options.method, path, q);
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: data));
  }

  dynamic _route(String method, String path, Map<String, String> q) {
    if (path.startsWith('/auth/local')) return {'jwt': 'demo-token'};
    if (path == '/users/me') return {'id': 'u1', 'username': '2022UCS1234', 'email': _email, 'student': 's1'};
    if (path == '/students/me') return _student;
    if (path == '/students/resumes') return {'resumes': _student['resume']};
    if (path.startsWith('/students/my_applied')) {
      return [
        for (final e in _events.take(3)) {'id': 'a${e['id']}', 'company_event': e},
      ];
    }
    if (path.startsWith('/announcements/subtypes')) return ['Placement', 'Internship', 'Shortlist', 'Update'];
    if (path.startsWith('/announcements/')) {
      final id = path.split('/').last;
      return _notices.firstWhere((n) => n['id'] == id, orElse: () => _notices.first);
    }
    if (path == '/announcements') {
      final start = int.tryParse(q['_start'] ?? '0') ?? 0;
      if (q.containsKey('event_id')) return _notices.take(3).toList();
      final type = q['type'];
      final list = _notices.where((n) => type == null || n['type'] == type).toList();
      return list.skip(start).take(12).toList();
    }
    if (path.startsWith('/companies/')) {
      return {
        'name': 'Google',
        'info': '<p>Google LLC is a technology company focused on search, cloud computing and AI.</p>',
        'company_category': 'Dream',
        'company_turnover': r'$300B+',
        'events': [1, 2],
      };
    }
    if (path.startsWith('/company-events/is_student_eligible')) {
      final id = path.split('/').last;
      return {
        'eligible': {
          'status': id != 'e3',
          'conditions': {
            'already_applied': id == 'e2',
            'already_placed': false,
            'cgpa': id == 'e3',
            'cgpa_not_updated': false,
            'batch': false,
            'branch': false,
            'degree': false,
            'backlogs': false,
            'ban': false,
            'gender': false,
            'form_uploaded': false,
          },
        },
      };
    }
    if (path.startsWith('/company-events/apply')) return {'ok': true};
    if (path.startsWith('/company-events/live-')) {
      return {
        ..._events[4],
        'id': path.split('/').last,
        'company': {'Name': 'Flipkart'},
        'jobtitle': 'Software Development Engineer I',
      };
    }
    if (path.startsWith('/company-events/')) {
      final id = path.split('/').last;
      return _events.firstWhere((e) => e['id'] == id, orElse: () => _events.first);
    }
    if (path == '/company-events') {
      final start = int.tryParse(q['_start'] ?? '0') ?? 0;
      // A "freshly listed" company that changes every minute, so background
      // alerts can be previewed in demo mode.
      final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final live = {
        ..._events[4],
        'id': 'live-$minute',
        'company': {'Name': 'Flipkart'},
        'jobtitle': 'Software Development Engineer I',
        'type': 'FTE',
        'lastDate': _in(6),
      };
      return [live, ..._events].skip(start).take(14).toList();
    }
    if (path.startsWith('/registrations/')) return 'Withdrawn successfully';
    if (path == '/ims/auth/captcha') return {'captchaImage': _captchaPng};
    if (path.startsWith('/ims/') || path.startsWith('/students/cgpa-update') || path.startsWith('/students/drop')) {
      return {'success': true};
    }
    if (path == '/forms') {
      return [
        {
          '_id': 'f1',
          'name': 'Pre-placement Undertaking 2026',
          'is_blocking': true,
          'file': {'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf'},
        },
        {
          '_id': 'f2',
          'name': 'Medical Fitness Certificate',
          'is_blocking': false,
          'file': {'url': ''},
        },
      ];
    }
    if (path == '/form-uploads/me') {
      return [
        {
          '_id': 'u1',
          'form': {'_id': 'f2', 'name': 'Medical Fitness Certificate'},
          'status': 'PENDING',
          'message': '',
          'createdAt': _ago(2),
          'file': {'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf'},
        },
      ];
    }
    if (path == '/nocs/student') {
      return {
        'applications': [
          {
            'id': 'n1',
            'company': 'Microsoft',
            'address': 'DLF Cyber City',
            'city': 'Gurugram',
            'state': 'Haryana',
            'pinCode': '122002',
            'start': '2026-05-15',
            'end': '2026-07-15',
            'source': 'On_Campus',
            'allowed': true,
            'noc_link': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf',
            'createdAt': _ago(20),
          },
          {
            'id': 'n2',
            'company': 'Zomato',
            'address': 'Sector 44',
            'city': 'Gurugram',
            'state': 'Haryana',
            'pinCode': '122003',
            'start': '2026-06-01',
            'end': '2026-08-01',
            'source': 'Off_Campus',
            'createdAt': _ago(3),
          },
        ],
      };
    }
    if (path == '/feedbacks' && method == 'GET') {
      return [
        {
          'id': 'fb1',
          'feedback_type': 'query',
          'feedback_data': 'When will the Google OA results be announced?',
          'isResolved': true,
          'feedback_reply': 'Results will be shared on the portal by Friday evening.',
          'resolved_by': 'TnP Office',
          'resolved_date': _ago(1),
          'createdAt': _ago(3),
        },
        {
          'id': 'fb2',
          'feedback_type': 'suggestion',
          'feedback_data': 'Please add calendar reminders for application deadlines.',
          'isResolved': false,
          'createdAt': _ago(1),
        },
      ];
    }
    return {'ok': true};
  }

  static String _ago(int days, [int hours = 0]) =>
      DateTime.now().subtract(Duration(days: days, hours: hours)).toUtc().toIso8601String();
  static String _in(int days, [int hours = 0]) =>
      DateTime.now().add(Duration(days: days, hours: hours)).toUtc().toIso8601String();

  static const _email = 'aarav.sharma.ug22@nsut.ac.in';

  static final Map<String, dynamic> _student = {
    'id': 's1',
    'Name': 'Aarav Sharma',
    'rollNumber': '2022UCS1234',
    'email': _email,
    'personal_email': 'aarav.sharma@gmail.com',
    'branch': 'CSE',
    'degree': 'BTech',
    'batch': '2026',
    'campus': 'Main',
    'gender': 'Male',
    'blood_group': 'B+',
    'contact_number': '9876543210',
    'alt_contact_number': '9123456780',
    'perm_address': '12, Green Park, New Delhi',
    'present_address': 'Hostel 3, NSUT Dwarka',
    'aadhar': '123412341234',
    'pan': 'ABCDE1234F',
    'dob': '14/8/2004',
    'category': 'GENERAL',
    'cgpa': 8.72,
    'cgpa_10th': 95.2,
    'cgpa_12th': 92.4,
    'graduation_gpa': -1,
    'backlogs': 0,
    'bans': 0,
    'cgpa_before_drop': 8.61,
    'sem1_gpa': 8.4,
    'sem2_gpa': 8.6,
    'sem3_gpa': 8.9,
    'sem4_gpa': 8.5,
    'sem5_gpa': 9.1,
    'sem6_gpa': 8.8,
    'isCgpaUpdated': true,
    'cgpaUpdateEnabled': true,
    'allowed_in_next_season': true,
    'resume': [
      {
        '_id': 'r1',
        'name': 'Aarav_Sharma_SDE.pdf',
        'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf',
      },
      {
        '_id': 'r2',
        'name': 'Aarav_Sharma_ML.pdf',
        'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf',
      },
    ],
    'allSemGPA': {
      'courseWiseData': [
        {
          'courseCode': 'CS301',
          'courseTitle': 'Operating Systems',
          'courseType': 'Core',
          'credits': '4',
          'creditPoints': '36',
          'gradeLetter': 'A+',
        },
        {
          'courseCode': 'CS302',
          'courseTitle': 'Computer Networks',
          'courseType': 'Core',
          'credits': '4',
          'creditPoints': '28',
          'gradeLetter': 'B+',
        },
        {
          'courseCode': 'HS201',
          'courseTitle': 'Economics',
          'courseType': 'Humanities',
          'credits': '2',
          'creditPoints': '12',
          'gradeLetter': 'B',
        },
        {
          'courseCode': 'CS303',
          'courseTitle': 'Compiler Design',
          'courseType': 'Core',
          'credits': '4',
          'creditPoints': '40',
          'gradeLetter': 'O',
        },
        {
          'courseCode': 'MA201',
          'courseTitle': 'Probability & Statistics',
          'courseType': 'Basic Science',
          'credits': '4',
          'creditPoints': '24',
          'gradeLetter': 'B',
        },
      ],
      'semesterWiseData': [
        {'totalCreditPoints': '1520', 'totalCredit': '176'},
      ],
    },
  };

  static final List<Map<String, dynamic>> _events = [
    {
      'id': 'e1',
      'company': {'Name': 'Google'},
      'jobtitle': 'Software Engineer, University Graduate',
      'type': 'FTE',
      'status': 'Open',
      'lastDate': _in(2, 5),
      'placeOfPosting': 'Bengaluru',
      'batch': '2026',
      'stipend': '₹ 32 LPA',
      'stipend_info': 'Base ₹22L + stocks + joining bonus',
      'cgpa': '7.0',
      'category': 'dream',
      'backlogs': '0',
      'apc': 'Riya (CSE) - 98xxxxxx10\nKabir (IT) - 97xxxxxx22',
      'additional_info': 'Online assessment on HackerRank.',
      'description':
          'Build and ship large-scale systems used by billions.\n\nRequirements:\n• Strong DSA fundamentals\n• Proficiency in one of C++, Java, Go or Python',
      'branchesAllowed': [
        {'degree': 'BTech', 'branch': 'CSE'},
        {'degree': 'BTech', 'branch': 'IT'},
        {'degree': 'BTech', 'branch': 'CSAI'},
        {'degree': 'MTech', 'branch': 'PCS'},
      ],
      'attachments': [
        {'name': 'Job Description.pdf', 'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf'},
      ],
      'is_additional_ques': true,
      'additional_ques': [
        {
          'ques': 'Preferred location?',
          'type': 'single',
          'options': ['Bengaluru', 'Hyderabad', 'Gurugram'],
          'expectedAns': '',
        },
        {'ques': 'GitHub profile URL', 'type': 'text', 'expectedAns': 'https://github.com/…'},
      ],
      'optional_criteria': true,
    },
    {
      'id': 'e2',
      'company': {'Name': 'Microsoft'},
      'jobtitle': 'SWE Intern (Summer 2026)',
      'type': 'Internship+PPO',
      'status': 'Open',
      'lastDate': _in(5),
      'placeOfPosting': 'Hyderabad',
      'batch': '2026',
      'stipend': '₹ 1.25 L / month',
      'cgpa': '7.5',
      'category': 'dream',
      'backlogs': '0',
      'apc': 'Ananya (ECE)',
      'description': 'Two-month internship with PPO opportunity.',
      'branchesAllowed': [
        {'degree': 'BTech', 'branch': 'CSE'},
      ],
    },
    {
      'id': 'e3',
      'company': {'Name': 'Goldman Sachs'},
      'jobtitle': 'Analyst — Engineering',
      'type': 'FTE',
      'status': 'Open',
      'lastDate': _in(1, 3),
      'placeOfPosting': 'Bengaluru',
      'batch': '2026',
      'stipend': '₹ 28 LPA',
      'cgpa': '9.0',
      'category': 'dream',
      'backlogs': '0',
      'apc': 'Dev (CSE)',
      'description': 'Engineering Analyst role.',
      'branchesAllowed': [
        {'degree': 'BTech', 'branch': 'CSE'},
      ],
    },
    {
      'id': 'e4',
      'company': {'Name': 'Zomato'},
      'jobtitle': 'Product Analyst',
      'type': 'Internship',
      'status': 'Closed',
      'lastDate': _ago(4),
      'placeOfPosting': 'Gurugram',
      'batch': '2026',
      'stipend': '₹ 60k / month',
      'cgpa': '6.5',
      'category': 'normal',
      'backlogs': '1',
      'apc': 'Neha (IT)',
      'description': 'Analytics internship.',
      'branchesAllowed': [],
    },
    {
      'id': 'e5',
      'company': {'Name': 'Atlassian'},
      'jobtitle': 'Graduate Software Engineer',
      'type': 'Internship+FTE',
      'status': 'Open',
      'lastDate': _in(9),
      'placeOfPosting': 'Remote',
      'batch': '2026',
      'stipend': '₹ 54 LPA',
      'cgpa': '8.0',
      'category': 'dream',
      'backlogs': '0',
      'apc': 'Riya (CSE)',
      'description': 'Graduate role.',
      'branchesAllowed': [],
    },
  ];

  static final List<Map<String, dynamic>> _notices = [
    {
      'id': 'n1',
      'title': 'Google SWE — Online Assessment schedule',
      'company': 'Google',
      'company_id': 'c1',
      'event_id': 'e1',
      'type': 'CompanyEvent',
      'tag': 'Placement',
      'published_at': _ago(0, 2),
      'batches': ['2027'],
      'degrees': ['BTech', 'MTech'],
      'content':
          '<p>The online assessment for <b>Google SWE</b> will be held on <b>Saturday, 10 AM</b>.</p><ul><li>Duration: 90 minutes</li><li>Platform: HackerRank</li></ul><p>Links will be mailed to registered students.</p>',
      'attachment': [
        {
          'name': 'OA Instructions.pdf',
          'url': 'https://tnpstudent.s3.ap-south-1.amazonaws.com/Placement+Policy.pdf',
          'size': 245.3,
          'ext': '.pdf',
        },
      ],
    },
    {
      'id': 'n2',
      'title': 'Shortlist: Microsoft SWE Intern interviews',
      'company': 'Microsoft',
      'type': 'CompanyEvent',
      'tag': 'Shortlist',
      'published_at': _ago(0, 9),
      'content':
          '[{"insert":"Congratulations to the shortlisted students! Interviews start "},{"insert":"tomorrow","attributes":{"bold":true}},{"insert":".\\n"}]',
    },
    {
      'id': 'n3',
      'title': 'Pre-placement undertaking submission deadline',
      'type': 'General',
      'tag': 'Update',
      'published_at': _ago(1),
      'content': 'All students must upload the signed undertaking in Forms & Docs before the deadline.',
    },
    {
      'id': 'n4',
      'title': 'Atlassian — Graduate SWE registrations open',
      'company': 'Atlassian',
      'type': 'CompanyEvent',
      'tag': 'Internship+FTE',
      'published_at': _ago(2),
      'content': '<p>Register on the portal before the deadline.</p>',
    },
    {
      'id': 'n5',
      'title': 'Resume review workshop this Friday',
      'type': 'General',
      'tag': 'Event',
      'published_at': _ago(3),
      'content': 'Join the TnP cell for a resume review workshop in the seminar hall.',
    },
    {
      'id': 'n6',
      'title': 'Zomato Product Analyst internship results',
      'company': 'Zomato',
      'type': 'CompanyEvent',
      'tag': 'Internship',
      'published_at': _ago(5),
      'content': 'Results have been declared. Selected students will be contacted by HR.',
    },
  ];

  /// A tiny 2-colour PNG standing in for the IMS captcha in demo mode.
  static const _captchaPng =
      'data:image/png;base64,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';
}
