import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import 'input_group.dart';
import '../icons/app_icons.dart';
import 'avatar.dart';

/// Dato di navigazione per la sidebar
class AppSidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  // Opzionale: widget leading (es. avatar utente). Se presente, sostituisce l'icona.
  final Widget? leading;
  const AppSidebarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.leading,
  });
}

/// Sidebar scura, collassabile, con sezione "Preferiti".
/// Desktop‑first: collassa automaticamente sotto 1280px.
class AppSidebar extends StatelessWidget {
  final List<AppSidebarItem> items;
  final List<AppSidebarItem> favorites;
  final int selectedIndex;
  final bool? collapsed; // se null, decide in base ai breakpoint
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String>? onSearch; // nuovo: callback ricerca
  final VoidCallback? onSettings; // nuovo: azione impostazioni
  final VoidCallback? onProfile; // nuovo: azione profilo
  final VoidCallback? onLogout; // nuovo: azione logout

  const AppSidebar({
    super.key,
    required this.items,
    this.favorites = const [],
    this.selectedIndex = 0,
    this.collapsed,
    this.onToggle,
    this.onSearch,
    this.onSettings,
    this.onProfile,
    this.onLogout,
  });

  static const double _expandedWidth = 240;
  static const double _collapsedWidth = 72;

  bool _isCollapsed(BuildContext context) {
    if (collapsed != null) {
      return collapsed!;
    }
    final w = MediaQuery.of(context).size.width;
    return w < 1280; // breakpoints: <1280 collassato
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = context.tokens;
    final dt = theme.extension<DefaultTokens>();
    final isCollapsed = _isCollapsed(context);
    final width = isCollapsed ? _collapsedWidth : _expandedWidth;
    final spacing = dt?.spacingUnit ?? 8.0;

    return Container(
      width: width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: gt.background,
        border: Border(right: BorderSide(color: gt.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header / logo area minimal
          Padding(
            padding: EdgeInsets.all(spacing * 2),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(AppIcons.dashboard,
                    color: theme.colorScheme.primary),
                if (!isCollapsed) ...[
                  SizedBox(width: spacing * 1.5),
                  // Nome applicazione
                  Text('Earon', style: theme.textTheme.titleMedium),
                ],
                const Spacer(),
                if (!isCollapsed)
                  _buildUserAvatar(AppAvatarSize.md),
                if (!isCollapsed && onToggle != null)
                  IconButton(
                    tooltip: 'Collassa',
                    onPressed: () => onToggle?.call(true),
                    icon: const Icon(AppIcons.chevronLeft),
                  ),
                if (isCollapsed && onToggle != null)
                  IconButton(
                    tooltip: 'Espandi',
                    onPressed: () => onToggle?.call(false),
                    icon: const Icon(AppIcons.chevronRight),
                  ),
              ],
            ),
          ),

          // Ricerca tra il nome dell’app e "Dashboard"
          if (onSearch != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCollapsed ? spacing : spacing * 2,
                0,
                isCollapsed ? spacing : spacing * 2,
                spacing * 1.5,
              ),
              child: isCollapsed
                  ? Align(
                      alignment: Alignment.center,
                      child: Tooltip(
                        message: 'Cerca',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => onSearch?.call(''),
                          child: Padding(
                            padding: EdgeInsets.all(spacing * 1.5),
                            child: const Icon(AppIcons.search),
                          ),
                        ),
                      ),
                    )
                  : AppInputGroup(
                      hintText: 'Cerca…',
                      leading: const Icon(AppIcons.search),
                      onSubmitted: onSearch,
                    ),
            ),

          // Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: spacing * 0.5),
              children: [
                for (int i = 0; i < items.length; i++)
                  _SidebarItemTile(
                    item: items[i],
                    selected: i == selectedIndex,
                    collapsed: isCollapsed,
                  ),
                if (favorites.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCollapsed ? spacing : spacing * 2,
                      spacing * 3,
                      spacing * 2,
                      spacing,
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.star,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 18),
                        if (!isCollapsed) ...[
                          SizedBox(width: spacing * 1.5),
                          Text('Preferiti',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                  for (final f in favorites)
                    _SidebarItemTile(
                        item: f, selected: false, collapsed: isCollapsed),
                ],
              ],
            ),
          ),

          // Footer: impostazioni e logout come righe centrate a fondo sidebar
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: isCollapsed ? spacing * 1.5 : spacing * 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Separatore sopra la sezione Impostazioni, allineato alla larghezza delle tile
                Container(
                  height: theme.dividerTheme.thickness ?? 1,
                  margin: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? spacing : spacing * 2,
                  ),
                  color: gt.border,
                ),
                SizedBox(height: spacing),

                _SidebarItemTile(
                  item: AppSidebarItem(
                    icon: AppIcons.settings,
                    label: 'Impostazioni',
                    onTap: onSettings,
                  ),
                  selected: false,
                  collapsed: isCollapsed,
                ),
                if (isCollapsed)
                  _SidebarItemTile(
                    item: AppSidebarItem(
                      icon: AppIcons.person,
                      leading: _buildUserAvatar(AppAvatarSize.sm),
                      label: 'Profilo',
                      onTap: onProfile,
                    ),
                    selected: false,
                    collapsed: isCollapsed,
                  ),
                _SidebarItemTile(
                  item: AppSidebarItem(
                    icon: AppIcons.logout,
                    label: 'Logout',
                    onTap: onLogout,
                  ),
                  selected: false,
                  collapsed: isCollapsed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Crea un AppAvatar con i dati dell'utente corrente
  Widget _buildUserAvatar(AppAvatarSize size) {
    // Usa l'avatar utente con caricamento da Supabase Storage (Signed URL)
    // Mappa AppAvatarSize -> radius per _UserAvatar
    final double radius = switch (size) {
      AppAvatarSize.sm => 12,
      AppAvatarSize.md => 16,
      AppAvatarSize.lg => 20,
    };
    return _UserAvatar(radius: radius);
  }
}

class _SidebarItemTile extends StatefulWidget {
  final AppSidebarItem item;
  final bool selected;
  final bool collapsed;
  const _SidebarItemTile(
      {required this.item, required this.selected, required this.collapsed});

  @override
  State<_SidebarItemTile> createState() => _SidebarItemTileState();
}

class _SidebarItemTileState extends State<_SidebarItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = context.tokens;
    final dt = theme.extension<DefaultTokens>();
    final rr = theme.extension<ShadcnRadii>();
    final spacing = dt?.spacingUnit ?? 8.0;
    final isActive = widget.selected || _hovered;
    final baseColor = isActive
        ? (dt?.sidebarOnPrimary ?? gt.foreground)
        : theme.colorScheme.onSurfaceVariant;
    final bgColor = isActive
        ? (dt?.sidebarPrimary ?? gt.muted)
        : Colors.transparent;

    final child = Container(
      width: double.infinity,
      height: 44,
      margin: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? spacing : spacing * 2,
        vertical: spacing * 0.5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: rr?.sm ?? BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? spacing : spacing * 1.5,
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (widget.item.leading != null)
              widget.item.leading!
            else
              Icon(widget.item.icon, color: baseColor),
            if (!widget.collapsed) ...[
              SizedBox(width: spacing * 1.5),
              Expanded(
                child: Text(
                  widget.item.label,
                  style:
                      theme.textTheme.labelLarge?.copyWith(color: baseColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Tooltip(
      message: widget.collapsed ? widget.item.label : '',
      waitDuration: dt?.durationBase ?? const Duration(milliseconds: 160),
      child: InkWell(
        borderRadius: rr?.sm ?? BorderRadius.circular(6),
        onTap: widget.item.onTap,
        onHover: (h) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hovered = h);
          });
        },
        child: child,
      ),
    );
  }
}

/// Avatar utente: legge prima il percorso in `profiles.avatar_path` nel bucket privato `avatars`,
/// genera una Signed URL e la usa. In assenza/errore, fallback ai metadati conosciuti
/// (`picture`, `avatar_url`, `image`, `image_url`) e infine alle iniziali.
class _UserAvatar extends StatefulWidget {
  final double radius;
  const _UserAvatar({this.radius = 12});

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class AvatarCache {
  static String? url;
  static Uint8List? bytes;
  static String? path;
  static DateTime? updatedAt;
  static void clear() {
    url = null;
    bytes = null;
    path = null;
    updatedAt = null;
  }
}

class _UserAvatarState extends State<_UserAvatar> {
  String? _signedUrl;
  Uint8List? _bytes;
  String? _lastPath;
  bool _downloadAttempted = false;
  late final Map<String, dynamic>? _meta;
  late final String? _email;
  String? _precachedUrl; // per evitare precache duplicati

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    if (meta is Map) {
      _meta = Map<String, dynamic>.from(meta as Map);
    } else {
      _meta = null;
    }
    _email = user?.email;
    // seed iniziale da cache per evitare flicker quando il widget viene ricreato
    if (AvatarCache.bytes != null && AvatarCache.bytes!.isNotEmpty) {
      _bytes = AvatarCache.bytes;
    }
    if (AvatarCache.url != null && AvatarCache.url!.isNotEmpty) {
      _signedUrl = AvatarCache.url;
      _precachedUrl = AvatarCache.url;
      // precache dell'immagine di rete se già disponibile in cache
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_precachedUrl != null) {
          precacheImage(NetworkImage(_precachedUrl!), context);
        }
      });
    }
    _loadAvatarFromStorage();
  }

  Future<void> _downloadAvatar(String path) async {
    if (_downloadAttempted) {
      return;
    }
    _downloadAttempted = true;
    try {
      final sb = Supabase.instance.client;
      final Uint8List data = await sb.storage.from('avatars').download(path);
      if (data.isNotEmpty) {
        debugPrint('[Avatar] download ok bytes=${data.length}');
        AvatarCache.bytes = data;
        AvatarCache.url = null;
        AvatarCache.path = path;
        AvatarCache.updatedAt = DateTime.now();
        if (mounted) {
          setState(() => _bytes = data);
        }
      } else {
        debugPrint('[Avatar] download returned empty');
      }
    } catch (e) {
      debugPrint('[Avatar] download failed: $e');
    }
  }

  Future<String?> _findCandidatePath(String fileName, String uid) async {
    final sb = Supabase.instance.client;
    final dirs = <String>[
      'users/$uid',
      'users',
      'profiles/$uid',
      'profiles',
      ''
    ];
    for (final dir in dirs) {
      try {
        final objs = await sb.storage.from('avatars').list(path: dir);
        final list = (objs as List);
        // match esatto del nome
        bool exact = false;
        for (final o in list) {
          try {
            final n = (o is Map) ? (o['name'] as String?) : (o.name as String?);
            if (n == fileName) {
              exact = true;
              break;
            }
          } catch (_) {}
        }
        if (exact) {
          final p = dir.isEmpty ? fileName : '$dir/$fileName';
          debugPrint('[Avatar] fallback match exact in "$dir" → $p');
          return p;
        }
        // nomi tipici
        const candidates = ['avatar.png', 'avatar.jpg', 'avatar.jpeg'];
        for (final c in candidates) {
          bool found = false;
          for (final o in list) {
            try {
              final n =
                  (o is Map) ? (o['name'] as String?) : (o.name as String?);
              if (n == c) {
                found = true;
                break;
              }
            } catch (_) {}
          }
          if (found) {
            final p = dir.isEmpty ? c : '$dir/$c';
            debugPrint('[Avatar] fallback match common "$c" in "$dir" → $p');
            return p;
          }
        }
        debugPrint('[Avatar] fallback probe dir="$dir" → count=${list.length}');
      } catch (e) {
        debugPrint('[Avatar] fallback list failed dir="$dir": $e');
      }
    }
    return null;
  }

  Future<void> _loadAvatarFromStorage() async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      return;
    }
    try {
      final prof = await sb
          .from('profiles')
          .select('avatar_path, avatar_updated_at')
          .eq('user_id', uid)
          .limit(1)
          .maybeSingle();

      var path = prof?['avatar_path'] as String?;
      if (path != null) {
        path = path.trim();
        if (path.startsWith('/')) path = path.substring(1);
        if (path.startsWith('avatars/')) {
          path = path.substring('avatars/'.length);
        }
      }

      if (path != null && path.isNotEmpty) {
        _lastPath = path;
        debugPrint('[Avatar] uid=$uid path=$path');

        final dir =
            path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
        final name = path.contains('/')
            ? path.substring(path.lastIndexOf('/') + 1)
            : path;
        try {
          final objs = await sb.storage.from('avatars').list(path: dir);
          final list = (objs as List);
          final match = list.any((o) {
            try {
              return (o.name == name) || (o['name'] == name);
            } catch (_) {
              return false;
            }
          });
          debugPrint(
              '[Avatar] list check dir="$dir" name="$name" → count=${list.length} match=$match');
          if (!match) {
            final fallbackPath = await _findCandidatePath(name, uid);
            if (fallbackPath != null) {
              debugPrint('[Avatar] using fallback path: $fallbackPath');
              _lastPath = fallbackPath;
            }
          }
        } catch (e) {
          debugPrint('[Avatar] list check failed: $e');
        }

        final effectivePath = _lastPath ?? path;
        dynamic res = await sb.storage
            .from('avatars')
            .createSignedUrl(effectivePath, 60 * 60 * 24);
        debugPrint(
            '[Avatar] createSignedUrl res type=${res.runtimeType} value=$res');

        String? signed;
        if (res is String) {
          signed = res;
        } else {
          try {
            signed = (res.signedUrl as String?);
          } catch (_) {
            try {
              signed = (res['signedUrl'] as String?);
            } catch (_) {
              try {
                signed = (res['signed_url'] as String?);
              } catch (_) {
                try {
                  signed = (res.data as String?);
                } catch (_) {}
              }
            }
          }
        }

        if (signed != null && signed.isNotEmpty) {
          final updatedAt = prof?['avatar_updated_at'];
          if (updatedAt != null) {
            final v = updatedAt.toString();
            signed = signed.contains('?') ? '$signed&v=$v' : '$signed?v=$v';
            AvatarCache.updatedAt = DateTime.tryParse(v) ?? DateTime.now();
          }
          debugPrint('[Avatar] signedUrl length=${signed.length}');
          AvatarCache.url = signed;
          AvatarCache.bytes = null;
          AvatarCache.path = effectivePath;
          if (mounted) {
            setState(() {
              _signedUrl = signed;
              // precache per evitare micro scatto al primo paint
              if (_precachedUrl != signed) {
                _precachedUrl = signed;
                // post-frame per avere un context valido
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  precacheImage(NetworkImage(signed!), context);
                });
              }
            });
          }
        } else {
          debugPrint(
              '[Avatar] createSignedUrl returned empty for path=$effectivePath');
          await _downloadAvatar(effectivePath);
        }
      } else {
        debugPrint('[Avatar] nessun avatar_path per uid=$uid');
      }
    } catch (e) {
      debugPrint('[Avatar] errore caricamento: $e');
      if (_lastPath != null && _lastPath!.isNotEmpty) {
        await _downloadAvatar(_lastPath!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.radius * 2;
    final meta = _meta;
    final email = _email;

    String? url = _signedUrl;
    // placeholder sempre pronto: bytes se disponibili, altrimenti iniziali
    Widget placeholder;
    if (_bytes != null) {
      placeholder = ClipOval(
        child: Image.memory(
          _bytes!,
          width: d,
          height: d,
          fit: BoxFit.cover,
        ),
      );
    } else {
      placeholder = _InitialsCircle(
          radius: widget.radius, initials: _initials(meta, email));
    }

    if (url == null && meta != null) {
      final dynamic picture = meta['picture'];
      final dynamic avatarUrl = meta['avatar_url'];
      final dynamic image = meta['image'];
      final dynamic imageUrl = meta['image_url'];
      if (picture is String && picture.isNotEmpty) {
        url = picture;
      } else if (avatarUrl is String && avatarUrl.isNotEmpty) {
        url = avatarUrl;
      } else if (image is String && image.isNotEmpty) {
        url = image;
      } else if (imageUrl is String && imageUrl.isNotEmpty) {
        url = imageUrl;
      }
    }

    if (url != null) {
      return SizedBox(
        width: d,
        height: d,
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // layer di placeholder subito visibile
              placeholder,
              // layer di immagine di rete che fa fade-in quando il primo frame è pronto
              Image.network(
                url,
                width: d,
                height: d,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  return AnimatedOpacity(
                    opacity: frame == null ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  if (_lastPath != null) {
                    Future.microtask(() => _downloadAvatar(_lastPath!));
                  }
                  return const SizedBox
                      .shrink(); // lasciamo il placeholder sotto
                },
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(width: d, height: d, child: placeholder);
  }

  String _initials(Map<String, dynamic>? meta, String? email) {
    String? name;
    if (meta != null) {
      final candidates = [
        meta['full_name'],
        meta['name'],
        meta['display_name'],
        meta['preferred_username'],
      ];
      for (final c in candidates) {
        if (c is String && c.trim().isNotEmpty) {
          name = c.trim();
          break;
        }
      }
      if (name == null) {
        final given = meta['given_name'];
        final family = meta['family_name'];
        if (given is String &&
            given.isNotEmpty &&
            family is String &&
            family.isNotEmpty) {
          name = '$given $family';
        }
      }
      if (name == null) {
        final first = meta['first_name'];
        final last = meta['last_name'];
        if (first is String &&
            first.isNotEmpty &&
            last is String &&
            last.isNotEmpty) {
          name = '$first $last';
        }
      }
    }

    if (name == null && email != null && email.isNotEmpty) {
      final base = email.split('@').first;
      name = base.replaceAll(RegExp(r'[_\.-]+'), ' ');
    }

    if (name == null || name.trim().isEmpty) return 'U';

    final tokens =
        name.trim().split(RegExp(r"\s+")).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 2) {
      final a = tokens.first.characters.first;
      final b = tokens[1].characters.first;
      return (a + b).toUpperCase();
    }
    return tokens.first.characters.first.toUpperCase();
  }
}

class _InitialsCircle extends StatelessWidget {
  final double radius;
  final String initials;
  const _InitialsCircle({required this.radius, required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Usa colori del tema per un contrasto chiaro
    final bg = theme.colorScheme.primary;
    final fg = theme.colorScheme.onPrimary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
