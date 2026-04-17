import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/mail_tm_api.dart';
import 'core/models.dart';
import 'features/auth/session_controller.dart';
import 'features/inbox/inbox_controller.dart';
import 'features/settings/theme_controller.dart';
import 'shared/date_time_ext.dart';
import 'theme/app_theme.dart';

class MailnexaApp extends StatefulWidget {
  const MailnexaApp({super.key});

  @override
  State<MailnexaApp> createState() => _MailnexaAppState();
}

class _MailnexaAppState extends State<MailnexaApp> {
  late final MailTmApi _api;
  late final SessionController _session;
  late final InboxController _inbox;
  late final ThemeController _theme;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _api = MailTmApi();
    _session = SessionController(_api);
    _inbox = InboxController(_api);
    _theme = ThemeController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _theme.load();
    await _session.loadStoredSession();
    await _session.fetchDomains();
    if (_session.token != null) {
      await _inbox.refresh(_session.token!);
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
    _inbox.dispose();
    _theme.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    final token = _session.token;
    if (token == null) {
      return;
    }
    _timer = Timer.periodic(Duration(seconds: _inbox.refreshSeconds), (_) {
      _inbox.refresh(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_theme, _session, _inbox]),
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Mailnexa',
          debugShowCheckedModeBanner: false,
          themeMode: _theme.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: _RootView(
            session: _session,
            inbox: _inbox,
            theme: _theme,
            onStartRefresh: _startAutoRefresh,
          ),
        );
      },
    );
  }
}

class _RootView extends StatelessWidget {
  const _RootView({
    required this.session,
    required this.inbox,
    required this.theme,
    required this.onStartRefresh,
  });

  final SessionController session;
  final InboxController inbox;
  final ThemeController theme;
  final VoidCallback onStartRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mailnexa'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Theme',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (session.isAuthenticated)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () {
                inbox.clear();
                session.logout();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: session.isAuthenticated
                ? _InboxScreen(session: session, inbox: inbox, onStartRefresh: onStartRefresh)
                : _EntryScreen(session: session, inbox: inbox, onStartRefresh: onStartRefresh),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: <ThemeMode>{theme.mode},
                onSelectionChanged: (Set<ThemeMode> value) => theme.setTheme(value.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Persist session on this browser'),
                value: session.persistSession,
                onChanged: session.setPersistSession,
              ),
              const SizedBox(height: 8),
              const Text('Mailnexa is fully client-side and talks directly to mail.tm.'),
            ],
          ),
        );
      },
    );
  }
}

class _EntryScreen extends StatefulWidget {
  const _EntryScreen({required this.session, required this.inbox, required this.onStartRefresh});

  final SessionController session;
  final InboxController inbox;
  final VoidCallback onStartRefresh;

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  final TextEditingController _localPart = TextEditingController();
  final TextEditingController _loginEmail = TextEditingController();
  final TextEditingController _loginPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localPart.text = widget.session.generateLocalPart();
  }

  @override
  void dispose() {
    _localPart.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDomains = widget.session.domains.isNotEmpty;
    final color = Theme.of(context).colorScheme;

    return ListView(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Fast temporary inboxes', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Create or open an inbox in seconds.'),
                const SizedBox(height: 20),
                if (widget.session.loadingDomains)
                  const LinearProgressIndicator()
                else if (!hasDomains)
                  Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.session.error ?? 'No domains available right now.')),
                      TextButton(onPressed: widget.session.fetchDomains, child: const Text('Retry')),
                    ],
                  )
                else
                  _CreateAccountForm(
                    localPart: _localPart,
                    domains: widget.session.domains,
                    busy: widget.session.busy,
                    onGenerate: () => _localPart.text = widget.session.generateLocalPart(),
                    onCreate: (String domain) async {
                      final ok = await widget.session.createAndLogin(localPart: _localPart.text, domain: domain);
                      if (!mounted || !ok || widget.session.token == null) {
                        return;
                      }
                      await widget.inbox.refresh(widget.session.token!);
                      widget.onStartRefresh();
                    },
                  ),
                if (widget.session.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(widget.session.error!, style: TextStyle(color: color.error)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Open existing inbox', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(controller: _loginEmail, decoration: const InputDecoration(labelText: 'Email address')),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.session.busy
                      ? null
                      : () async {
                          final ok = await widget.session.loginExisting(
                            email: _loginEmail.text,
                            valuePassword: _loginPassword.text,
                          );
                          if (!mounted || !ok || widget.session.token == null) {
                            return;
                          }
                          await widget.inbox.refresh(widget.session.token!);
                          widget.onStartRefresh();
                        },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Open inbox'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateAccountForm extends StatefulWidget {
  const _CreateAccountForm({
    required this.localPart,
    required this.domains,
    required this.busy,
    required this.onGenerate,
    required this.onCreate,
  });

  final TextEditingController localPart;
  final List<MailDomain> domains;
  final bool busy;
  final VoidCallback onGenerate;
  final Future<void> Function(String domain) onCreate;

  @override
  State<_CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<_CreateAccountForm> {
  late String _selectedDomain;

  @override
  void initState() {
    super.initState();
    _selectedDomain = widget.domains.first.domain;
  }

  @override
  void didUpdateWidget(covariant _CreateAccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.domains.any((MailDomain d) => d.domain == _selectedDomain)) {
      _selectedDomain = widget.domains.first.domain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: widget.localPart,
                decoration: const InputDecoration(labelText: 'Mailbox name'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedDomain,
                items: widget.domains
                    .map((MailDomain d) => DropdownMenuItem<String>(
                          value: d.domain,
                          child: Text('@${d.domain}'),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _selectedDomain = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: widget.busy ? null : () => widget.onCreate(_selectedDomain),
              icon: const Icon(Icons.mark_email_read_rounded),
              label: const Text('Create inbox'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : widget.onGenerate,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Quick generate'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InboxScreen extends StatelessWidget {
  const _InboxScreen({required this.session, required this.inbox, required this.onStartRefresh});

  final SessionController session;
  final InboxController inbox;
  final VoidCallback onStartRefresh;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    final token = session.token!;

    Future<void> refresh() async {
      await inbox.refresh(token);
      onStartRefresh();
    }

    return Column(
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    session.address ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy email',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: session.address ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: 'Refresh inbox',
                  onPressed: inbox.loading ? null : refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: 'Create new inbox',
                  onPressed: () {
                    inbox.clear();
                    session.logout();
                  },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isNarrow
              ? _InboxStackMobile(session: session, inbox: inbox)
              : Row(
                  children: <Widget>[
                    Expanded(flex: 4, child: _MessageList(token: token, inbox: inbox)),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: _MessageDetailPanel(token: token, inbox: inbox)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _InboxStackMobile extends StatelessWidget {
  const _InboxStackMobile({required this.session, required this.inbox});

  final SessionController session;
  final InboxController inbox;

  @override
  Widget build(BuildContext context) {
    final token = session.token!;
    return inbox.selectedId == null
        ? _MessageList(token: token, inbox: inbox)
        : _MessageDetailPanel(token: token, inbox: inbox, backToList: inbox.deselect);
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.token, required this.inbox});

  final String token;
  final InboxController inbox;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: inbox.loading
          ? const Center(child: CircularProgressIndicator())
          : inbox.messages.isEmpty
              ? const Center(child: Text('Inbox is empty'))
              : ListView.separated(
                  itemCount: inbox.messages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final message = inbox.messages[index];
                    final selected = inbox.selectedId == message.id;
                    return ListTile(
                      selected: selected,
                      onTap: () => inbox.selectMessage(token, message.id),
                      title: Text(message.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${message.fromAddress} • ${message.createdAt.toCompact()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: message.seen ? const Icon(Icons.mark_email_read_rounded) : null,
                    );
                  },
                ),
    );
  }
}

class _MessageDetailPanel extends StatelessWidget {
  const _MessageDetailPanel({required this.token, required this.inbox, this.backToList});

  final String token;
  final InboxController inbox;
  final VoidCallback? backToList;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: inbox.loadingMessage
            ? const Center(child: CircularProgressIndicator())
            : inbox.selected == null
                ? const Center(child: Text('Select a message'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (backToList != null)
                        TextButton.icon(
                          onPressed: backToList,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                      Text(inbox.selected!.subject, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('From: ${inbox.selected!.fromAddress}'),
                      Text('Received: ${inbox.selected!.createdAt.toCompact()}'),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            inbox.selected!.text.isNotEmpty
                                ? inbox.selected!.text
                                : 'No plain-text body available. Open in your mail client if needed.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: () => inbox.deleteSelected(token),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete message'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
