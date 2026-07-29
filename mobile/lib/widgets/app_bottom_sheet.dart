import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AppBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const AppBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Scrollable body prevents yellow/black overflow stripes on long sheets.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.page,
          right: AppSpacing.page,
          top: 12,
          bottom: bottomInset + AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: p.text),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a modal sheet that can still read [AppState] via Provider.
///
/// Modal routes sit beside [HomeShell], not under the AppState provider, so we
/// re-attach the instance from [context] for Consumers inside the sheet.
Future<T?> showAppBottomSheet<T>(BuildContext context, Widget child) {
  final p = ThemePalette.of(context);
  final appState = context.read<AppState>();
  final parentTheme = Theme.of(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Theme(
        data: parentTheme.copyWith(
          listTileTheme: ListTileThemeData(
            tileColor: Colors.transparent,
            textColor: p.text,
            iconColor: p.textMuted,
            selectedTileColor: p.surface3,
          ),
        ),
        child: child,
      ),
    ),
  );
}
