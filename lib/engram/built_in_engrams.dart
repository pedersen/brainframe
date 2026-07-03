import 'package:flutter/services.dart' show AssetBundle;

import 'asset_engram_store.dart';
import 'engram.dart';

/// Well-known, stable id of the bundled tutorial engram.
const String builtinTutorialId = 'builtin-tutorial';

/// Well-known, stable id of the bundled help engram.
const String builtinHelpId = 'builtin-help';

/// Asset-path prefix the tutorial engram's files live under.
const String tutorialAssetPrefix = 'assets/engrams/tutorial/';

/// Asset-path prefix the help engram's files live under.
const String helpAssetPrefix = 'assets/engrams/help/';

/// The two read-only engrams bundled with the app (Decision 5).
///
/// They are always present, are reached through a read-only [AssetEngramStore],
/// never appear in the user registry, and cannot be forgotten or deleted. Their
/// ids are fixed so "last opened" and cross-references key on them stably. The
/// [bundle] is injectable for tests; it defaults to `rootBundle`.
List<Engram> builtInEngrams({AssetBundle? bundle}) => [
      Engram(
        id: builtinTutorialId,
        displayName: 'Tutorial',
        readOnly: true,
        store: AssetEngramStore(assetPrefix: tutorialAssetPrefix, bundle: bundle),
      ),
      Engram(
        id: builtinHelpId,
        displayName: 'Help',
        readOnly: true,
        store: AssetEngramStore(assetPrefix: helpAssetPrefix, bundle: bundle),
      ),
    ];

/// Whether [id] belongs to a built-in engram, which cannot be forgotten.
bool isBuiltInEngramId(String id) =>
    id == builtinTutorialId || id == builtinHelpId;
