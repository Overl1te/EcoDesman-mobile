import "../models/eco_map_point_detail.dart";
import "../models/map_overview.dart";

abstract class MapRepository {
  Future<MapOverview> fetchOverview();

  Future<EcoMapPointDetail> fetchPointDetail(int pointId);

  Future<void> createReview({
    required int pointId,
    required int rating,
    required String body,
  });
}
