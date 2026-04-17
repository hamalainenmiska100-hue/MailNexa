class MailDomain {
  const MailDomain({required this.id, required this.domain});

  final String id;
  final String domain;

  factory MailDomain.fromJson(Map<String, dynamic> json) {
    return MailDomain(
      id: json['id'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
    );
  }
}

class MailAccount {
  const MailAccount({required this.id, required this.address, required this.createdAt});

  final String id;
  final String address;
  final DateTime? createdAt;

  factory MailAccount.fromJson(Map<String, dynamic> json) {
    return MailAccount(
      id: json['id'] as String? ?? '',
      address: json['address'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class MailToken {
  const MailToken({required this.token, required this.id});

  final String token;
  final String id;

  factory MailToken.fromJson(Map<String, dynamic> json) {
    return MailToken(
      token: json['token'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.fromAddress,
    required this.fromName,
    required this.subject,
    required this.intro,
    required this.seen,
    required this.createdAt,
  });

  final String id;
  final String fromAddress;
  final String fromName;
  final String subject;
  final String intro;
  final bool seen;
  final DateTime? createdAt;

  factory InboxMessage.fromJson(Map<String, dynamic> json) {
    final fromRaw = json['from'];
    final from = fromRaw is Map ? fromRaw : const <Object?, Object?>{};
    return InboxMessage(
      id: json['id'] as String? ?? '',
      fromAddress: from['address']?.toString() ?? 'Unknown',
      fromName: from['name']?.toString() ?? '',
      subject: json['subject'] as String? ?? 'No subject',
      intro: json['intro'] as String? ?? '',
      seen: json['seen'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class MessageDetail {
  const MessageDetail({
    required this.id,
    required this.fromAddress,
    required this.fromName,
    required this.subject,
    required this.text,
    required this.html,
    required this.createdAt,
  });

  final String id;
  final String fromAddress;
  final String fromName;
  final String subject;
  final String text;
  final List<String> html;
  final DateTime? createdAt;

  String get displayText {
    final normalizedText = text.trim();
    if (normalizedText.isNotEmpty) {
      return normalizedText;
    }

    for (final fragment in html) {
      final cleaned = _htmlToText(fragment);
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return '';
  }

  factory MessageDetail.fromJson(Map<String, dynamic> json) {
    final fromRaw = json['from'];
    final from = fromRaw is Map ? fromRaw : const <Object?, Object?>{};
    final htmlRaw = json['html'];
    return MessageDetail(
      id: json['id'] as String? ?? '',
      fromAddress: from['address']?.toString() ?? 'Unknown',
      fromName: from['name']?.toString() ?? '',
      subject: json['subject'] as String? ?? 'No subject',
      text: json['text'] as String? ?? '',
      html: htmlRaw is List ? htmlRaw.map((e) => e.toString()).toList() : const <String>[],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  static String _htmlToText(String input) {
    var value = input
        .replaceAll(RegExp(r'(?is)<(script|style)[^>]*>.*?</\1>'), ' ')
        .replaceAll(RegExp(r'(?i)<br\\s*/?>'), '\n')
        .replaceAll(RegExp(r'(?i)</(p|div|li|tr|h[1-6])>'), '\n');
    value = value.replaceAll(RegExp(r'(?is)<[^>]+>'), ' ');
    value = value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    value = value.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return value.trim();
  }
}
