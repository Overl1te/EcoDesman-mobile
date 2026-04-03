import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/error_message.dart";
import "../../data/repositories/map_repository_impl.dart";
import "../../domain/models/eco_map_point_detail.dart";
import "../../domain/models/map_overview.dart";

final mapControllerProvider = AsyncNotifierProvider<MapController, MapOverview>(
  MapController.new,
);

final mapPointDetailProvider = FutureProvider.family<EcoMapPointDetail, int>((
  ref,
  pointId,
) {
  return ref.read(mapRepositoryProvider).fetchPointDetail(pointId);
});

class MapController extends AsyncNotifier<MapOverview> {
  @override
  Future<MapOverview> build() {
    return ref.read(mapRepositoryProvider).fetchOverview();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(mapRepositoryProvider).fetchOverview();
    });
  }

  String toErrorMessage(Object error) {
    return humanizeNetworkError(
      error,
      fallback: "Не удалось загрузить точки на карте",
    );
  }
}
