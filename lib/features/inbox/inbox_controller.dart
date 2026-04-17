import 'package:flutter/foundation.dart';

import '../../core/mail_tm_api.dart';
import '../../core/models.dart';

class InboxController extends ChangeNotifier {
  InboxController(this._api);

  final MailTmApi _api;

  List<InboxMessage> messages = const <InboxMessage>[];
  MessageDetail? selected;
  String? selectedId;
  bool loading = false;
  bool loadingMessage = false;
  String? error;
  int refreshSeconds = 30;

  Future<void> refresh(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      messages = await _api.fetchMessages(token: token);
      if (selectedId != null && messages.every((m) => m.id != selectedId)) {
        selectedId = null;
        selected = null;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectMessage(String token, String id) async {
    selectedId = id;
    loadingMessage = true;
    error = null;
    notifyListeners();
    try {
      selected = await _api.fetchMessageDetail(token: token, id: id);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingMessage = false;
      notifyListeners();
    }
  }

  Future<void> deleteSelected(String token) async {
    final id = selectedId;
    if (id == null) {
      return;
    }
    loadingMessage = true;
    error = null;
    notifyListeners();
    try {
      await _api.deleteMessage(token: token, id: id);
      messages = messages.where((m) => m.id != id).toList();
      selected = null;
      selectedId = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loadingMessage = false;
      notifyListeners();
    }
  }

  void setRefreshSeconds(int value) {
    refreshSeconds = value;
    notifyListeners();
  }

  void deselect() {
    selectedId = null;
    selected = null;
    notifyListeners();
  }

  void clear() {
    messages = const <InboxMessage>[];
    selected = null;
    selectedId = null;
    loading = false;
    loadingMessage = false;
    error = null;
    notifyListeners();
  }
}
