import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:maplibre/maplibre.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../domain/models/eco_map_category.dart";
import "../../domain/models/eco_map_point.dart";
import "../../domain/models/map_bounds.dart";
import "../controllers/map_controller.dart" as map_feature;
import "../map_point_style.dart";
import "../widgets/map_point_details_sheet.dart";

class MapPlaceholderScreen extends ConsumerStatefulWidget {
  const MapPlaceholderScreen({super.key});

  @override
  ConsumerState<MapPlaceholderScreen> createState() =>
      _MapPlaceholderScreenState();
}

class _MapPlaceholderScreenState extends ConsumerState<MapPlaceholderScreen> {
  static const Geographic _nizhnyNovgorodCenter = Geographic(
    lon: 43.974881,
    lat: 56.315048,
  );
  static const String _openFreeMapLibertyStyleUrl =
      "https://tiles.openfreemap.org/styles/liberty";
  static const double _initialZoom = 11.8;
  static const double _twoDimensionalPitch = 0;
  static const double _threeDimensionalPitch = 52;
  static const double _threeDimensionalBearing = -16;
  static const double _tapRadius = 34;

  MapController? _mapController;
  int? _selectedPointId;
  String _selectedCategorySlug = "all";
  bool _isThreeDimensional = true;
  bool _filtersExpanded = true;

  LngLatBounds _toLngLatBounds(MapBounds bounds) {
    return LngLatBounds(
      longitudeWest: bounds.west,
      longitudeEast: bounds.east,
      latitudeSouth: bounds.south,
      latitudeNorth: bounds.north,
    );
  }

  Future<void> _focusPoint(EcoMapPoint point) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    setState(() {
      _selectedPointId = point.id;
    });

    await controller.animateCamera(
      center: Geographic(lon: point.longitude, lat: point.latitude),
      zoom: 13.6,
      pitch: _isThreeDimensional
          ? _threeDimensionalPitch
          : _twoDimensionalPitch,
      bearing: _isThreeDimensional ? _threeDimensionalBearing : 0,
      nativeDuration: const Duration(milliseconds: 850),
      webMaxDuration: const Duration(milliseconds: 850),
    );

    if (!mounted) {
      return;
    }

    await showMapPointDetailsSheet(context, pointId: point.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPointId = null;
    });
  }

  Future<void> _togglePerspective() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final nextIsThreeDimensional = !_isThreeDimensional;
    setState(() {
      _isThreeDimensional = nextIsThreeDimensional;
    });

    await controller.animateCamera(
      pitch: nextIsThreeDimensional
          ? _threeDimensionalPitch
          : _twoDimensionalPitch,
      bearing: nextIsThreeDimensional ? _threeDimensionalBearing : 0,
      nativeDuration: const Duration(milliseconds: 700),
      webMaxDuration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _openExternalLink(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  bool _matchesCategory(EcoMapPoint point) {
    if (_selectedCategorySlug == "all") {
      return true;
    }

    return point.categories.any((item) => item.slug == _selectedCategorySlug);
  }

  String _selectedCategoryTitle(List<EcoMapCategory> categories) {
    if (_selectedCategorySlug == "all") {
      return "Все точки";
    }

    for (final category in categories) {
      if (category.slug == _selectedCategorySlug) {
        return category.title;
      }
    }

    return "Фильтры";
  }

  int _countForCategory(String slug, List<EcoMapPoint> points) {
    if (slug == "all") {
      return points.length;
    }

    return points
        .where((point) => point.categories.any((item) => item.slug == slug))
        .length;
  }

  EcoMapPoint? _selectedPoint(List<EcoMapPoint> points) {
    for (final point in points) {
      if (point.id == _selectedPointId) {
        return point;
      }
    }

    return null;
  }

  List<EcoMapCategory> _sortedCategories(List<EcoMapCategory> categories) {
    final sorted = [...categories];
    sorted.sort((left, right) {
      final priorityDiff =
          getCategoryPriority(right) - getCategoryPriority(left);
      if (priorityDiff != 0) {
        return priorityDiff;
      }
      return left.title.compareTo(right.title);
    });
    return sorted;
  }

  MapPointAppearance _appearanceForPoint(EcoMapPoint point) {
    return getMapPointAppearance(
      getPrimaryMapCategory(
        point.categories,
        primaryCategory: point.primaryCategory,
      ),
    );
  }

  Feature<Point> _toFeature(EcoMapPoint point) {
    return Feature(
      id: point.id.toString(),
      geometry: Point(Geographic(lon: point.longitude, lat: point.latitude)),
      properties: {"title": point.title},
    );
  }

  List<_PointLayerGroup> _groupPointsByAppearance(List<EcoMapPoint> points) {
    final groupedFeatures = <String, List<Feature<Point>>>{};
    final groupedAppearances = <String, MapPointAppearance>{};

    for (final point in points) {
      final appearance = _appearanceForPoint(point);
      final key =
          "${appearance.color.toARGB32()}:${appearance.strokeColor.toARGB32()}:${appearance.selectedColor.toARGB32()}";
      groupedAppearances[key] = appearance;
      groupedFeatures.putIfAbsent(key, () => []).add(_toFeature(point));
    }

    return [
      for (final entry in groupedFeatures.entries)
        _PointLayerGroup(
          appearance: groupedAppearances[entry.key]!,
          points: entry.value,
        ),
    ];
  }

  Future<void> _handleMapTap(
    MapEvent event,
    List<EcoMapPoint> filteredPoints,
  ) async {
    if (event is! MapEventClick && event is! MapEventLongClick) {
      return;
    }
    final userInput = event as MapEventUserInput;

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    EcoMapPoint? tappedPoint;
    var bestDistance = double.infinity;

    for (final point in filteredPoints) {
      final screenLocation = controller.toScreenLocation(
        Geographic(lon: point.longitude, lat: point.latitude),
      );
      final distance = (userInput.screenPoint - screenLocation).distance;
      if (distance <= _tapRadius && distance < bestDistance) {
        tappedPoint = point;
        bestDistance = distance;
      }
    }

    if (tappedPoint == null) {
      if (_selectedPointId != null) {
        setState(() {
          _selectedPointId = null;
        });
      }
      return;
    }

    await _focusPoint(tappedPoint);
  }

  IconData _categoryIcon(String slug) {
    switch (slug) {
      case "marketplace":
        return Icons.storefront_outlined;
      case "batteries":
        return Icons.battery_charging_full_outlined;
      case "paper":
        return Icons.description_outlined;
      case "eco-center":
        return Icons.eco_outlined;
      case "park":
        return Icons.park_outlined;
      case "metal":
      case "scrap":
        return Icons.precision_manufacturing_outlined;
      case "plastic":
        return Icons.recycling_outlined;
      case "glass":
        return Icons.wine_bar_outlined;
      case "electronics":
        return Icons.memory_outlined;
      case "clothes":
        return Icons.checkroom_outlined;
      case "viewpoint":
        return Icons.visibility_outlined;
      case "museum":
        return Icons.museum_outlined;
      case "nature":
        return Icons.forest_outlined;
      case "embankment":
        return Icons.water_outlined;
      case "sports":
        return Icons.directions_run_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(map_feature.mapControllerProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return AppErrorState(
          title: "Не удалось загрузить карту",
          message: ref
              .read(map_feature.mapControllerProvider.notifier)
              .toErrorMessage(error),
          onRetry: () =>
              ref.read(map_feature.mapControllerProvider.notifier).refresh(),
        );
      },
      data: (overview) {
        final sortedCategories = _sortedCategories(overview.categories);
        final filteredPoints = overview.points
            .where(_matchesCategory)
            .toList(growable: false);

        if (overview.points.isEmpty) {
          return const AppEmptyState(
            title: "Точек пока нет",
            message: "Когда на сервере появятся точки, они отобразятся здесь.",
          );
        }

        final theme = Theme.of(context);
        final selectedCategoryTitle = _selectedCategoryTitle(sortedCategories);
        final selectedPoint = _selectedPoint(filteredPoints);
        final pointLayers = _groupPointsByAppearance([
          for (final point in filteredPoints)
            if (point.id != selectedPoint?.id) point,
        ]);
        final selectedAppearance = selectedPoint == null
            ? null
            : _appearanceForPoint(selectedPoint);
        final selectedPointFeatures = selectedPoint == null
            ? const <Feature<Point>>[]
            : <Feature<Point>>[_toFeature(selectedPoint)];

        return Stack(
          children: [
            MapLibreMap(
              key: const ValueKey("mobile-map-openfreemap-liberty"),
              options: MapOptions(
                initStyle: _openFreeMapLibertyStyleUrl,
                initCenter: _nizhnyNovgorodCenter,
                initZoom: _initialZoom,
                initPitch: _isThreeDimensional
                    ? _threeDimensionalPitch
                    : _twoDimensionalPitch,
                initBearing: _isThreeDimensional ? _threeDimensionalBearing : 0,
                minZoom: 10.5,
                maxZoom: 18,
                minPitch: 0,
                maxPitch: 60,
                maxBounds: _toLngLatBounds(overview.bounds),
                androidTextureMode: true,
                androidMode: AndroidPlatformViewMode.tlhc_hc,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onEvent: (event) => _handleMapTap(event, filteredPoints),
              layers: [
                for (final layer in pointLayers)
                  CircleLayer(
                    points: layer.points,
                    radius: 9,
                    color: layer.appearance.color,
                    strokeWidth: 4,
                    strokeColor: layer.appearance.strokeColor,
                  ),
                if (selectedPointFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedPointFeatures,
                    radius: 18,
                    color: selectedAppearance!.haloColor,
                    blur: 0.2,
                    strokeWidth: 2,
                    strokeColor: selectedAppearance.strokeColor,
                  ),
                if (selectedPointFeatures.isNotEmpty)
                  CircleLayer(
                    points: selectedPointFeatures,
                    radius: 10,
                    color: selectedAppearance!.selectedColor,
                    strokeWidth: 4,
                    strokeColor: selectedAppearance.selectedStrokeColor,
                  ),
              ],
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MapFilterPanel(
                          points: overview.points,
                          categories: sortedCategories,
                          selectedCategoryTitle: selectedCategoryTitle,
                          selectedSlug: _selectedCategorySlug,
                          pointsCount: filteredPoints.length,
                          isThreeDimensional: _isThreeDimensional,
                          isExpanded: _filtersExpanded,
                          categoryIconBuilder: _categoryIcon,
                          categoryColorBuilder: (category) =>
                              getMapPointAppearance(category).color,
                          countForCategory: _countForCategory,
                          onCategorySelected: (slug) {
                            if (slug == _selectedCategorySlug) {
                              return;
                            }

                            setState(() {
                              _selectedCategorySlug = slug;
                              _selectedPointId = null;
                            });
                          },
                          onToggleExpanded: () {
                            setState(() {
                              _filtersExpanded = !_filtersExpanded;
                            });
                          },
                          onTogglePerspective: _togglePerspective,
                          onReset: _selectedCategorySlug == "all"
                              ? null
                              : () {
                                  setState(() {
                                    _selectedCategorySlug = "all";
                                    _selectedPointId = null;
                                  });
                                },
                        ),
                        if (filteredPoints.isEmpty) ...[
                          const SizedBox(height: 12),
                          _EmptyFilterCard(
                            onReset: () {
                              setState(() {
                                _selectedCategorySlug = "all";
                                _selectedPointId = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: SafeArea(
                    top: false,
                    child: _MapAttributionPill(
                      onOpenStreetMapTap: () => _openExternalLink(
                        "https://www.openstreetmap.org/copyright",
                      ),
                      onOpenMapTilesTap: () =>
                          _openExternalLink("https://www.openmaptiles.org/"),
                      onOpenFreeMapTap: () =>
                          _openExternalLink("https://openfreemap.org/"),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 14,
              right: 132,
              bottom: 14,
              child: IgnorePointer(
                ignoring: selectedPoint != null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: selectedPoint == null ? 1 : 0,
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.92,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "Нажмите на точку, чтобы открыть подробности",
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapFilterPanel extends StatelessWidget {
  const _MapFilterPanel({
    required this.points,
    required this.categories,
    required this.selectedCategoryTitle,
    required this.selectedSlug,
    required this.pointsCount,
    required this.isThreeDimensional,
    required this.isExpanded,
    required this.categoryIconBuilder,
    required this.categoryColorBuilder,
    required this.countForCategory,
    required this.onCategorySelected,
    required this.onToggleExpanded,
    required this.onTogglePerspective,
    required this.onReset,
  });

  final List<EcoMapPoint> points;
  final List<EcoMapCategory> categories;
  final String selectedCategoryTitle;
  final String selectedSlug;
  final int pointsCount;
  final bool isThreeDimensional;
  final bool isExpanded;
  final IconData Function(String slug) categoryIconBuilder;
  final Color Function(EcoMapCategory? category) categoryColorBuilder;
  final int Function(String slug, List<EcoMapPoint> points) countForCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTogglePerspective;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$selectedCategoryTitle · $pointsCount точек",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Фильтры",
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onToggleExpanded,
                tooltip: isExpanded ? "Скрыть фильтры" : "Показать фильтры",
                icon: const Icon(Icons.filter_alt_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onTogglePerspective,
                tooltip: isThreeDimensional
                    ? "Переключить в 2D"
                    : "Переключить в 3D",
                icon: Icon(
                  isThreeDimensional
                      ? Icons.view_in_ar_rounded
                      : Icons.flip_to_front_outlined,
                ),
              ),
              if (onReset != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onReset,
                  tooltip: "Сбросить фильтр",
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterOptionChip(
                      label: "Все",
                      count: countForCategory("all", points),
                      icon: Icons.apps_rounded,
                      accentColor: const Color(0xFF56616F),
                      selected: selectedSlug == "all",
                      onTap: () => onCategorySelected("all"),
                    ),
                    for (final category in categories) ...[
                      const SizedBox(width: 10),
                      _FilterOptionChip(
                        label: category.title,
                        count: countForCategory(category.slug, points),
                        icon: categoryIconBuilder(category.slug),
                        accentColor: categoryColorBuilder(category),
                        selected: selectedSlug == category.slug,
                        onTap: () => onCategorySelected(category.slug),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MapAttributionPill extends StatelessWidget {
  const _MapAttributionPill({
    required this.onOpenStreetMapTap,
    required this.onOpenMapTilesTap,
    required this.onOpenFreeMapTap,
  });

  final VoidCallback onOpenStreetMapTap;
  final VoidCallback onOpenMapTilesTap;
  final VoidCallback onOpenFreeMapTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          _AttributionLink(
            label: "OpenStreetMap",
            style: textStyle,
            onTap: onOpenStreetMapTap,
          ),
          Text("•", style: textStyle),
          _AttributionLink(
            label: "OpenMapTiles",
            style: textStyle,
            onTap: onOpenMapTilesTap,
          ),
          Text("•", style: textStyle),
          _AttributionLink(
            label: "OpenFreeMap",
            style: textStyle,
            onTap: onOpenFreeMapTap,
          ),
        ],
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(label, style: style),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedForeground =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Material(
      color: selected ? accentColor : accentColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? selectedForeground : accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? selectedForeground
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? selectedForeground.withValues(alpha: 0.16)
                      : accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$count",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? selectedForeground : accentColor,
                    fontWeight: FontWeight.w800,
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

class _PointLayerGroup {
  const _PointLayerGroup({required this.appearance, required this.points});

  final MapPointAppearance appearance;
  final List<Feature<Point>> points;
}

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "По текущему фильтру точек нет. Сбросьте фильтр и посмотрите все точки.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onReset, child: const Text("Сбросить")),
        ],
      ),
    );
  }
}
