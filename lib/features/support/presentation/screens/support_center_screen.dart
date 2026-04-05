import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../data/repositories/support_repository_impl.dart";
import "../../domain/models/support_models.dart";

class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  ConsumerState<SupportCenterScreen> createState() =>
      _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  final _botController = TextEditingController();
  Timer? _pollTimer;

  SupportKnowledgeResponse _knowledge = const SupportKnowledgeResponse.empty();
  List<SupportThreadSummary> _threads = const [];
  List<SupportReport> _reports = const [];
  SupportBotReply? _botReply;

  bool _isLoading = true;
  bool _isBotBusy = false;
  String? _error;
  String? _botError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _botController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _loadData(silent: true);
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    final authState = ref.read(authControllerProvider);
    final canAccessSupport = authState.user?.canAccessSupport ?? false;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final repository = ref.read(supportRepositoryProvider);
      final knowledge = await repository.fetchKnowledge();
      var threads = const <SupportThreadSummary>[];
      var reports = const <SupportReport>[];

      if (authState.isAuthenticated) {
        threads = await repository.fetchThreads(teamView: canAccessSupport);
        if (canAccessSupport) {
          reports = await repository.fetchTeamReports();
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _knowledge = knowledge;
        _threads = threads;
        _reports = reports;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить раздел помощи",
        );
      });
    }
  }

  Future<void> _askBot([String? prompt]) async {
    final query = (prompt ?? _botController.text).trim();
    if (query.length < 2) {
      return;
    }

    setState(() {
      _isBotBusy = true;
      _botError = null;
    });

    try {
      final reply = await ref.read(supportRepositoryProvider).askBot(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _botReply = reply;
        _botController.text = query;
        _isBotBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBotBusy = false;
        _botError = humanizeNetworkError(
          error,
          fallback: "Не удалось получить ответ мини-бота",
        );
      });
    }
  }

  Future<void> _openCreateThreadSheet() async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы написать в поддержку");
      return;
    }

    final input = await showModalBottomSheet<_CreateThreadInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CreateThreadSheet(),
    );

    if (input == null) {
      return;
    }

    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .createThread(
            subject: input.subject,
            body: input.body,
            category: input.category,
          );
      if (!mounted) {
        return;
      }
      await _loadData(silent: true);
      if (!mounted) {
        return;
      }
      context.push("/profile/support/thread/${thread.id}");
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось создать обращение"),
        isError: true,
      );
    }
  }

  Future<void> _moderateReport(SupportReport report) async {
    final authState = ref.read(authControllerProvider);
    if (!(authState.user?.canAccessSupport ?? false)) {
      return;
    }

    final input = await showModalBottomSheet<_ReportModerationInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ReportModerationSheet(report: report),
    );

    if (input == null) {
      return;
    }

    try {
      await ref
          .read(supportRepositoryProvider)
          .updateReport(
            reportId: report.id,
            status: input.status,
            resolutionNote: input.resolutionNote,
            removeTarget: input.removeTarget,
          );
      await _loadData(silent: true);
      if (!mounted) {
        return;
      }
      _showSnack("Жалоба обновлена");
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось обновить жалобу"),
        isError: true,
      );
    }
  }

  void _showKnowledgeEntry(SupportKnowledgeEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.title),
          content: SingleChildScrollView(child: Text(entry.answer)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Понятно"),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final canAccessSupport = user?.canAccessSupport ?? false;
    final unreadCount = _threads.fold<int>(
      0,
      (sum, item) => sum + item.unreadCount,
    );
    final openCount = _threads.where((item) => item.status != "closed").length;
    final newReportsCount = _reports
        .where((item) => item.status == "new")
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Справка и помощь"),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
            tooltip: "Обновить",
          ),
        ],
      ),
      floatingActionButton: authState.isAuthenticated
          ? FloatingActionButton.extended(
              onPressed: _openCreateThreadSheet,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text("Новое обращение"),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text("Раздел помощи временно недоступен"),
                    subtitle: Text(_error!),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _HeroStats(
                unreadCount: unreadCount,
                openCount: openCount,
                newReportsCount: newReportsCount,
                canAccessSupport: canAccessSupport,
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: authState.isAuthenticated
                    ? (canAccessSupport ? "Очередь поддержки" : "Мои обращения")
                    : "Частые проблемы",
                actionLabel: authState.isAuthenticated ? "Создать чат" : null,
                onAction: authState.isAuthenticated
                    ? _openCreateThreadSheet
                    : null,
              ),
              const SizedBox(height: 12),
              if (!authState.isAuthenticated)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.login)),
                    title: const Text("Войдите, чтобы писать в поддержку"),
                    subtitle: const Text(
                      "После входа появятся ваши чаты, история обращений и статусы жалоб.",
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go("/login"),
                  ),
                )
              else if (_threads.isEmpty)
                const AppEmptyState(
                  title: "Пока нет обращений",
                  message:
                      "Создайте первый чат с техподдержкой прямо из этого раздела.",
                )
              else
                ..._threads.map(
                  (thread) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ThreadCard(
                      thread: thread,
                      canAccessSupport: canAccessSupport,
                      onTap: () =>
                          context.push("/profile/support/thread/${thread.id}"),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Мини-бот"),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Опишите проблему, и бот подскажет подходящий FAQ или предложит открыть чат.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _botController,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: "Вопрос боту",
                          hintText: "Например: не вижу уведомления по жалобе",
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _knowledge.suggestedPrompts
                            .map(
                              (prompt) => ActionChip(
                                label: Text(prompt),
                                onPressed: () => _askBot(prompt),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _isBotBusy ? null : () => _askBot(),
                          icon: _isBotBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.smart_toy_outlined),
                          label: Text(_isBotBusy ? "Думаем..." : "Спросить"),
                        ),
                      ),
                      if (_botError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _botError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_botReply != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _botReply!.reply,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.45),
                              ),
                              if (_botReply!.matchedArticle != null) ...[
                                const SizedBox(height: 10),
                                ActionChip(
                                  label: Text(_botReply!.matchedArticle!.title),
                                  onPressed: () => _showKnowledgeEntry(
                                    _botReply!.matchedArticle!,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canAccessSupport) ...[
                const SizedBox(height: 24),
                _SectionTitle(title: "Жалобы на модерации"),
                const SizedBox(height: 12),
                if (_reports.isEmpty)
                  const AppEmptyState(
                    title: "Новых жалоб нет",
                    message:
                        "Когда пользователи пожалуются на посты, комментарии или отзывы на карте, они появятся здесь.",
                  )
                else
                  ..._reports.map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReportCard(
                        report: report,
                        onTap: () => _moderateReport(report),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              _SectionTitle(title: "FAQ и частые проблемы"),
              const SizedBox(height: 12),
              if (_knowledge.featured.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _knowledge.featured
                      .map(
                        (entry) => ActionChip(
                          label: Text(entry.title),
                          onPressed: () => _showKnowledgeEntry(entry),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (_knowledge.faq.isEmpty)
                const AppEmptyState(
                  title: "Справка пока пустая",
                  message:
                      "FAQ появится здесь, как только мы добавим материалы.",
                )
              else
                ..._knowledge.faq.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ExpansionTile(
                        title: Text(entry.title),
                        subtitle: Text(entry.category),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Text(
                            entry.answer,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({
    required this.unreadCount,
    required this.openCount,
    required this.newReportsCount,
    required this.canAccessSupport,
  });

  final int unreadCount;
  final int openCount;
  final int newReportsCount;
  final bool canAccessSupport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: "Непрочитанные",
                value: "$unreadCount",
                icon: Icons.mark_chat_unread_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: "Открытые чаты",
                value: "$openCount",
                icon: Icons.forum_outlined,
              ),
            ),
          ],
        ),
        if (canAccessSupport) ...[
          const SizedBox(height: 12),
          _StatCard(
            title: "Новые жалобы",
            value: "$newReportsCount",
            icon: Icons.flag_outlined,
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_comment_outlined),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.canAccessSupport,
    required this.onTap,
  });

  final SupportThreadSummary thread;
  final bool canAccessSupport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.subject,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                getSupportThreadCategoryLabel(thread.category),
                              ),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                            ),
                            Chip(
                              label: Text(
                                getSupportThreadStatusLabel(thread.status),
                              ),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                              backgroundColor: thread.status == "closed"
                                  ? theme.colorScheme.surfaceContainerHighest
                                  : theme.colorScheme.secondaryContainer,
                            ),
                            if (thread.hasUnread)
                              Chip(
                                label: Text("Новых: ${thread.unreadCount}"),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide.none,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                thread.lastMessagePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                canAccessSupport
                    ? "Автор: ${thread.createdBy.displayName}"
                    : "Обновлено ${formatPostDate(thread.lastMessageAt.toLocal())}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (canAccessSupport && thread.assignedTo != null) ...[
                const SizedBox(height: 6),
                Text(
                  "Назначено: ${thread.assignedTo!.displayName}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final SupportReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.targetLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(getSupportReportStatusLabel(report.status)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: report.status == "new"
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.secondaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(getSupportReportTargetLabel(report.targetType)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                  Chip(
                    label: Text(getSupportReportReasonLabel(report.reason)),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.details.isNotEmpty
                    ? report.details
                    : "Без дополнительных деталей",
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                "Отправил: ${report.reporter.displayName} · ${formatPostDate(report.createdAt.toLocal())}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateThreadInput {
  const _CreateThreadInput({
    required this.subject,
    required this.body,
    required this.category,
  });

  final String subject;
  final String body;
  final String category;
}

class _CreateThreadSheet extends StatefulWidget {
  const _CreateThreadSheet();

  @override
  State<_CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends State<_CreateThreadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  String _category = "general";

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CreateThreadInput(
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Новое обращение",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: "Категория"),
              items: const [
                DropdownMenuItem(value: "general", child: Text("Общее")),
                DropdownMenuItem(value: "account", child: Text("Аккаунт")),
                DropdownMenuItem(value: "content", child: Text("Контент")),
                DropdownMenuItem(value: "map", child: Text("Карта")),
                DropdownMenuItem(value: "report", child: Text("Жалоба")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: "Тема"),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 3) {
                  return "Коротко сформулируйте тему";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Сообщение",
                hintText:
                    "Опишите проблему, шаги воспроизведения и что уже пробовали.",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 6) {
                  return "Нужно немного больше деталей";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_outlined),
                label: const Text("Открыть чат"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportModerationInput {
  const _ReportModerationInput({
    required this.status,
    required this.resolutionNote,
    required this.removeTarget,
  });

  final String status;
  final String resolutionNote;
  final bool removeTarget;
}

class _ReportModerationSheet extends StatefulWidget {
  const _ReportModerationSheet({required this.report});

  final SupportReport report;

  @override
  State<_ReportModerationSheet> createState() => _ReportModerationSheetState();
}

class _ReportModerationSheetState extends State<_ReportModerationSheet> {
  final _noteController = TextEditingController();
  String _status = "in_review";
  bool _removeTarget = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _ReportModerationInput(
        status: _status,
        resolutionNote: _noteController.text.trim(),
        removeTarget: _removeTarget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Модерация жалобы",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(widget.report.targetLabel),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: "Статус"),
            items: const [
              DropdownMenuItem(value: "in_review", child: Text("В работе")),
              DropdownMenuItem(value: "resolved", child: Text("Решено")),
              DropdownMenuItem(value: "rejected", child: Text("Отклонено")),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _status = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: "Комментарий для чата",
              hintText: "Эта заметка отправится в историю обращения.",
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _removeTarget,
            title: const Text("Удалить контент-цель"),
            subtitle: const Text(
              "Используйте, если жалоба подтверждена и контент должен исчезнуть.",
            ),
            onChanged: (value) {
              setState(() {
                _removeTarget = value ?? false;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Сохранить решение"),
            ),
          ),
        ],
      ),
    );
  }
}
