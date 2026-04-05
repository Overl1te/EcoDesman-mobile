import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../data/repositories/support_repository_impl.dart";
import "../../domain/models/support_models.dart";

final helpCenterContentProvider = FutureProvider<HelpCenterContent>((ref) {
  return ref.watch(supportRepositoryProvider).fetchHelpCenterContent();
});

class HelpInfoScreen extends ConsumerWidget {
  const HelpInfoScreen({super.key});

  Future<void> _openDocument(
    BuildContext context,
    HelpDocument document,
  ) async {
    final uri = Uri.tryParse(document.pdfDownloadUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Некорректная ссылка для ${document.label}")),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Не удалось открыть ${document.label}")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(helpCenterContentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Справка")),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  "Не удалось загрузить справку",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (content) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.overview.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    content.overview.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => context.push("/profile/support"),
                        icon: const Icon(Icons.support_agent_outlined),
                        label: const Text("Перейти в помощь"),
                      ),
                      if (content.documents.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openDocument(context, content.documents.first),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text("Скачать PDF"),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final card in content.overview.cards) ...[
              _InfoCard(title: card.title, body: card.body),
              const SizedBox(height: 12),
            ],
            for (final block in content.serviceBlocks) ...[
              _InfoCard(title: block.title, body: block.body),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              "Юридические документы",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final document in content.documents)
              _LegalTile(
                document: document,
                onDownload: () => _openDocument(context, document),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.document, required this.onDownload});

  final HelpDocument document;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        title: Text(document.label),
        subtitle: Text(document.summary),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: document.approval.revision),
                _MetaChip(
                  label: "Вступает в силу: ${document.approval.effectiveDate}",
                ),
                _MetaChip(label: document.pdfFileName),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            document.summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.approval.status,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Утверждающее лицо: ${document.approval.approvedBy}, ${document.approval.approvedRole}.",
                ),
                const SizedBox(height: 6),
                Text("Основание: ${document.approval.approvalBasis}."),
                const SizedBox(height: 6),
                Text("Контакты: ${document.approval.contact}."),
                const SizedBox(height: 6),
                Text(document.approval.note),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
              label: const Text("Скачать PDF"),
            ),
          ),
          const SizedBox(height: 8),
          for (final section in document.sections)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final paragraph in section.paragraphs) ...[
                    Text(
                      paragraph,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 6),
                  ],
                  for (final bullet in section.bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "• $bullet",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
