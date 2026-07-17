import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/gen/app_localizations.dart';
import '../widgets/app_scaffold.dart';

/// Opens external URIs; injectable so tests can observe launches without the
/// url_launcher plugin. Returns true when the platform accepted the request.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// Resolves the app's version + build so the About screen can be pushed from
/// anywhere with a single call. Injectable for tests.
typedef AppInfoLoader = Future<PackageInfo> Function();

/// Pushes the [AboutScreen] as a full page, resolving the real version/build
/// first. This is the seam a future Settings screen reuses — it can either call
/// this to push About standalone, or embed [AboutScreen] directly.
Future<void> openAboutScreen(
  BuildContext context, {
  AppInfoLoader loadInfo = PackageInfo.fromPlatform,
}) async {
  final info = await loadInfo();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AboutScreen(
        version: info.version,
        buildNumber: info.buildNumber,
      ),
    ),
  );
}

/// The About screen: app identity, version, and ways to reach the product.
///
/// Recreates the Claude Design handoff layout (logo tile → name + tagline →
/// version pill → links card → footer) using the app's own theme rather than
/// the handoff's bespoke palette, so it stays adaptive and high-contrast/e-ink
/// safe. The single fixed colour is the logo tile: the PNG has a baked-in
/// near-black background, so it always sits on a dark tile to look intentional.
///
/// Stateless and self-contained — [openAboutScreen] supplies the version/build,
/// and everything else is derived from [Theme]/[AppLocalizations]. That keeps
/// it trivial to drop inside a Settings screen later.
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    super.key,
    required this.version,
    required this.buildNumber,
    this.launcher = _launchExternal,
    this.currentYear,
  });

  /// Semantic app version, e.g. "2.4.1".
  final String version;

  /// Build number, e.g. "1847".
  final String buildNumber;

  /// Opens the website/contact links. Defaults to the platform handler.
  final UriLauncher launcher;

  /// The current year, used to build the copyright span. Defaults to the real
  /// current year; injectable so tests stay deterministic.
  final int? currentYear;

  /// The year BrainFrame was first published. The copyright line starts here
  /// and grows into a range (`2026–2027`, …) as the years pass — it never
  /// drops the original year, and never implies a later first-publication year.
  static const int _foundingYear = 2026;

  /// The logo tile's fixed background in both themes (the logo PNG carries a
  /// baked-in near-black background).
  static const Color _logoTileColor = Color(0xFF05080C);

  static final Uri _websiteUri = Uri.parse('https://brainframe.tech/');
  static final Uri _contactUri = Uri.parse('mailto:getbrainframe@gmail.com');

  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.aboutTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(child: _LogoTile()),
                const SizedBox(height: 28),
                _identity(context, l10n),
                const SizedBox(height: 28),
                Align(child: _versionPill(context, l10n)),
                const SizedBox(height: 28),
                _LinksCard(
                  rows: [
                    _LinkRowData(
                      icon: Icons.public_outlined,
                      label: l10n.aboutWebsiteLabel,
                      value: l10n.aboutWebsiteValue,
                      onTap: () => launcher(_websiteUri),
                    ),
                    _LinkRowData(
                      icon: Icons.mail_outline,
                      label: l10n.aboutContactLabel,
                      value: l10n.aboutContactValue,
                      onTap: () => launcher(_contactUri),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _footer(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * (theme.textTheme.headlineMedium?.fontSize ?? 28),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            l10n.aboutTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _versionPill(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: scheme.onSurface,
    );
    final mutedStyle = valueStyle.copyWith(color: scheme.onSurfaceVariant);
    return Semantics(
      label: l10n.aboutVersionSemantics(version, buildNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _accentSoft(scheme),
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
                boxShadow: [
                  BoxShadow(color: scheme.primary, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'v$version', style: valueStyle),
                    TextSpan(text: ' · ', style: mutedStyle),
                    TextSpan(text: '${l10n.aboutBuild} ', style: mutedStyle),
                    TextSpan(text: buildNumber, style: valueStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The copyright span: just the founding year until the calendar moves past
  /// it, then a `2026–<current>` range. Guards against a current year earlier
  /// than founding (e.g. a misconfigured clock) by never showing a backwards
  /// range.
  String _copyrightYears(int current) => current <= _foundingYear
      ? '$_foundingYear'
      : '$_foundingYear–$current';

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Text(
      l10n.aboutFooter(_copyrightYears(currentYear ?? DateTime.now().year)),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    );
  }
}

/// The accent-soft fill used behind the version pill and link icon chips —
/// a low-opacity wash of the theme's primary, matching the handoff's
/// `--accent-soft` token while staying theme-driven.
Color _accentSoft(ColorScheme scheme) =>
    scheme.primary.withValues(alpha: scheme.brightness == Brightness.dark ? 0.12 : 0.08);

/// The 132×132 rounded logo tile with a radial accent glow behind the logo.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: AboutScreen._logoTileColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: _accentSoft(scheme),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: -8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.16),
                radius: 0.65,
                colors: [_accentSoft(scheme), Colors.transparent],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Image.asset(
            'brainframe.png',
            width: 118,
            height: 118,
            fit: BoxFit.cover,
          ),
        ],
      ),
    );
  }
}

/// Data for one row of the links card.
class _LinkRowData {
  const _LinkRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
}

/// The card holding the website + contact rows, with an inset divider between
/// them (aligned to the text column, not the icon chip).
class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.rows});

  final List<_LinkRowData> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: scheme.outlineVariant,
              ),
            _LinkRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.data});

  final _LinkRowData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${data.label}: ${data.value}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: data.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accentSoft(scheme),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(data.icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.06 * 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
