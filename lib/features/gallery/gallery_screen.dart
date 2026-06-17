// lib/features/gallery/gallery_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Gallery — user-facing. Shows a grid of published gallery images uploaded
// from the admin. Tapping opens a full-screen hero viewer.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/brightness_colors.dart';
import '../../data/models/gallery_item_model.dart';
import '../../data/repositories/gallery_repository.dart';
import '../../features/settings/cubit/settings_cubit.dart';
import '../../services/settings_service.dart';
import '../../shared/widgets/cached_image.dart';

const _kNavy  = Color(0xFF1B2A4A);
const _kGold  = Color(0xFFC9A84C);

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _repo = sl<GalleryRepository>();
  List<GalleryItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.watchPublished().listen(
      (items) => setState(() { _items = items; _loading = false; }),
      onError: (_) => setState(() => _loading = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isGreek = context.select<SettingsCubit, bool>(
      (c) => c.state.language == AppLanguage.greek,
    );

    return Scaffold(
      backgroundColor: BrightnessColors.bgDeep(brightness),
      body: SafeArea(
        child: Column(
          children: [
            _Header(isGreek: isGreek),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: BrightnessColors.gold(brightness), strokeWidth: 2))
                  : _items.isEmpty
                      ? _EmptyState(isGreek: isGreek)
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) => _ImageCard(
                            item: _items[i],
                            isGreek: isGreek,
                            brightness: brightness,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              isGreek ? 'Γκαλερί' : 'معرض الصور',
              style: TextStyle(
                fontFamily: isGreek ? null : 'Scheherazade',
                color: _kGold,
                fontSize: isGreek ? 18 : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image card ────────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.item,
    required this.isGreek,
    required this.brightness,
  });

  final GalleryItemModel item;
  final bool isGreek;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final name = (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;
    final tag  = 'gallery_${item.id}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullScreenViewer(
              item: item, heroTag: tag, isGreek: isGreek),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B2A4A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGold.withValues(alpha: 0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Hero(
                tag: tag,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: CachedImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: _fallback(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                name,
                textDirection:
                    isGreek ? TextDirection.ltr : TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: isGreek ? null : 'Scheherazade',
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: isGreek ? 11 : 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF253554),
    child: const Center(
      child: Text('✦', style: TextStyle(color: _kGold, fontSize: 28)),
    ),
  );
}

// ── Full-screen viewer ────────────────────────────────────────────────────────

class _FullScreenViewer extends StatelessWidget {
  const _FullScreenViewer({
    required this.item,
    required this.heroTag,
    required this.isGreek,
  });

  final GalleryItemModel item;
  final String heroTag;
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    final name =
        (isGreek && item.titleEl.isNotEmpty) ? item.titleEl : item.titleAr;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                child: CachedImage(
                  url: item.imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white38, size: 48),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        name,
                        textDirection: isGreek
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: isGreek ? null : 'Scheherazade',
                          color: Colors.white,
                          fontSize: isGreek ? 16 : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isGreek});
  final bool isGreek;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 56, color: _kGold.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            isGreek ? 'Δεν υπάρχουν εικόνες' : 'لا توجد صور',
            style: TextStyle(
              fontFamily: isGreek ? null : 'Scheherazade',
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: isGreek ? 15 : 18,
            ),
          ),
        ],
      ),
    );
  }
}
