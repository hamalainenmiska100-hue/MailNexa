import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class MailTmApi {
  MailTmApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'https://api.mail.tm';

  Future<List<MailDomain>> fetchDomains() async {
    final response = await _client.get(Uri.parse('$_baseUrl/domains?page=1'));
    _ensureSuccess(response, context: 'Unable to fetch domains');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final members = payload['hydra:member'] as List<dynamic>? ?? const <dynamic>[];
    return members
        .whereType<Map<String, dynamic>>()
        .map(MailDomain.fromJson)
        .where((domain) => domain.domain.isNotEmpty)
        .toList();
  }

  Future<void> createAccount({required String address, required String password}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/accounts'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'address': address,
        'password': password,
      }),
    );
    _ensureSuccess(response, context: 'Unable to create inbox');
  }

  Future<MailToken> authenticate({required String address, required String password}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/token'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'address': address,
        'password': password,
      }),
    );
    _ensureSuccess(response, context: 'Unable to sign in');
    return MailToken.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<InboxMessage>> fetchMessages({required String token}) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/messages?page=1'),
      headers: _authHeaders(token),
    );
    _ensureSuccess(response, context: 'Unable to load inbox');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final members = payload['hydra:member'] as List<dynamic>? ?? const <dynamic>[];
    return members.whereType<Map<String, dynamic>>().map(InboxMessage.fromJson).toList();
  }

  Future<MessageDetail> fetchMessageDetail({required String token, required String id}) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/messages/$id'),
      headers: _authHeaders(token),
    );
    _ensureSuccess(response, context: 'Unable to open message');
    return MessageDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMessage({required String token, required String id}) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/messages/$id'),
      headers: _authHeaders(token),
    );
    _ensureSuccess(response, context: 'Unable to delete message');
  }

  Map<String, String> get _headers => const <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, String> _authHeaders(String token) => <String, String>{
        ..._headers,
        'Authorization': 'Bearer $token',
      };

  void _ensureSuccess(http.Response response, {required String context}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String detail = 'Request failed (${response.statusCode}).';
    try {
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      final parsedDetail = parsed['detail'] as String?;
      if (parsedDetail != null && parsedDetail.isNotEmpty) {
        detail = parsedDetail;
      }
    } catch (_) {
      // fall through
    }

    throw MailTmException('$context. $detail');
  }
}

class MailTmException implements Exception {
  MailTmException(this.message);
  final String message;

  @override
  String toString() => message;
}
