import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../domain/models/eco_map_point_detail.dart";
import "../../domain/models/map_overview.dart";

final mapRemoteDataSourceProvider = Provider<MapRemoteDataSource>((ref) {
  return MapRemoteDataSource(ref.watch(apiClientProvider));
});

class MapRemoteDataSource {
  MapRemoteDataSource(this._dio);

  final Dio _dio;

  Future<MapOverview> fetchOverview() async {
    final response = await _dio.get("/map/overview");
    return MapOverview.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<EcoMapPointDetail> fetchPointDetail(int pointId) async {
    final response = await _dio.get("/map/points/$pointId");
    return EcoMapPointDetail.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> createReview({
    required int pointId,
    required int rating,
    required String body,
  }) async {
    await _dio.post(
      "/map/points/$pointId/reviews",
      data: {
        "rating": rating,
        "body": body,
      },
    );
  }
}
