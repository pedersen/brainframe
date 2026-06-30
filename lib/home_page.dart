import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme/app_settings.dart';
import 'theme/design_language.dart';
import 'widgets/app_scaffold.dart';

/// A minimal landing screen that exercises the adaptive shell: the
/// design-aware [AppScaffold], a built-in `.adaptive` toggle, an adaptive
/// dialog, and a design-aware primary button.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _eInkPreview = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'BrainFrame',
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Decorative: the heading below carries the accessible name.
                  ExcludeSemantics(
                    child: Image.asset(
                      'brainframe.png',
                      width: 128,
                      height: 128,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('BrainFrame', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Your second brain and e-reader.',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Adaptive toggle: a Cupertino switch on Apple, Material
                  // elsewhere — no branching needed from us.
                  SwitchListTile.adaptive(
                    value: _eInkPreview,
                    onChanged: (value) =>
                        setState(() => _eInkPreview = value),
                    title: const Text('E-ink preview'),
                    subtitle: const Text('Placeholder for a future setting'),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: 'Get started',
                    onPressed: () => _showWelcome(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWelcome(BuildContext context) {
    showAdaptiveDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Welcome'),
        content: const Text('BrainFrame is up and running.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// A primary action button rendered in the active design language. Flutter has
/// no `.adaptive` filled button, so this is a tiny design-aware helper rather
/// than a scattered platform check.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final design = AppSettings.of(context).designFor(context);
    return switch (design) {
      DesignLanguage.cupertino => CupertinoButton.filled(
          onPressed: onPressed,
          child: Text(label),
        ),
      DesignLanguage.material => FilledButton(
          onPressed: onPressed,
          child: Text(label),
        ),
    };
  }
}
