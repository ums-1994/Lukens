class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

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
  }) async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

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

      // Simulate email sending
      print('Sending email...');
      print('From: $from');
      print('To: ${to.join(', ')}');
      print('CC: ${cc.join(', ')}');
      print('Subject: $subject');
      print('Body: $body');

      // Simulate success
      return true;
    } catch (e) {
      print('Error sending email: $e');
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
    );
  }

  // Get available templates
  List<String> getAvailableTemplates() {
    return emailTemplates.keys.toList();
  }

  // Generate proposal link
  String generateProposalLink(String documentName, String companyName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://proposeit.app/view/$timestamp/${documentName.replaceAll(' ', '-').toLowerCase()}';
  }
}
