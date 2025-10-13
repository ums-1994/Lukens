import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  static const String baseUrl = 'http://localhost:8000';

  // Email templates
  static const Map<String, Map<String, String>> emailTemplates = {
    'Default Send Email': {
      'subject': '{documentName} - {companyName}',
      'body': '''Hi {clientName},

Take a look at our proposal and let me know if you have any questions:

{proposalLink}

Best regards,
{companyName}''',
    },
    'Thank you email': {
      'subject': 'Thank you for your interest - {documentName}',
      'body': '''Dear {clientName},

Thank you for your interest in our services. Please find attached our detailed proposal for your review.

{proposalLink}

We look forward to discussing this opportunity with you further.

Best regards,
{companyName}''',
    },
    'Reminder email': {
      'subject': 'Follow-up on {documentName} proposal',
      'body': '''Dear {clientName},

I wanted to follow up on the proposal we sent regarding {documentName}.

{proposalLink}

Please let me know if you have any questions or if you need any additional information.

Best regards,
{companyName}''',
    },
  };

  // Send email functionality
  Future<bool> sendEmail({
    required String from,
    required List<String> to,
    required List<String> cc,
    required String template,
    required String documentName,
    required String companyName,
    required String clientName,
    required String proposalLink,
    Map<String, dynamic>? proposalData,
    bool includePdf = true,
    bool includeDashboardLink = true,
  }) async {
    try {
      // Get template content
      final templateData =
          emailTemplates[template] ?? emailTemplates['Default Send Email']!;

      // Replace placeholders
      String subject = templateData['subject']!
          .replaceAll('{documentName}', documentName)
          .replaceAll('{companyName}', companyName)
          .replaceAll('{clientName}', clientName);

      String body = templateData['body']!
          .replaceAll('{documentName}', documentName)
          .replaceAll('{companyName}', companyName)
          .replaceAll('{clientName}', clientName)
          .replaceAll('{proposalLink}', proposalLink);

      // Convert body to HTML
      String htmlBody = '''
      <html>
      <body>
        <p>${body.replaceAll('\n', '<br>')}</p>
        <br>
        <a href="$proposalLink" style="background-color: #3498DB; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Click to view proposal</a>
      </body>
      </html>
      ''';

      // Extract name and email from 'from' field
      String fromName = from.split(' | ')[0];
      String fromEmail = from.split(' | ')[1];

      // Call Python backend to send email
      print('Sending email to: $baseUrl/send-proposal-email');
      print('Recipients: $to');
      print('CC: $cc');
      print('Subject: $subject');
      print('From Name: $fromName');
      print('From Email: $fromEmail');
      print('Proposal Data: $proposalData');

      final response = await http.post(
        Uri.parse('$baseUrl/send-proposal-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'to': to,
          'cc': cc,
          'subject': subject,
          'body': htmlBody,
          'from_name': fromName,
          'from_email': fromEmail,
          'proposal_data': proposalData,
          'include_pdf': includePdf,
          'include_dashboard_link': includeDashboardLink,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Email sent successfully!');
        return true;
      } else {
        print('Failed to send email. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException')) {
        print('Network error - backend might not be running');
      }
      return false;
    }
  }

  // Send test email
  Future<bool> sendTestEmail({
    required String from,
    required String testEmail,
    required String template,
    required String documentName,
    required String companyName,
    required String clientName,
    required String proposalLink,
    Map<String, dynamic>? proposalData,
    bool includePdf = true,
    bool includeDashboardLink = true,
  }) async {
    return await sendEmail(
      from: from,
      to: [testEmail],
      cc: [],
      template: template,
      documentName: documentName,
      companyName: companyName,
      clientName: clientName,
      proposalLink: proposalLink,
      proposalData: proposalData,
      includePdf: includePdf,
      includeDashboardLink: includeDashboardLink,
    );
  }

  // Get available templates
  List<String> getAvailableTemplates() {
    return emailTemplates.keys.toList();
  }

  // Generate proposal link
  String generateProposalLink(String documentName, String companyName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://proposify.app/view/$timestamp/${documentName.replaceAll(' ', '-').toLowerCase()}';
  }
}
