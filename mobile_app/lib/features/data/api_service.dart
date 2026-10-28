import 'dart:async';

import '../artifacts/artifact.dart';
import 'heritage_repository.dart';

abstract class ApiService {
  Future<List<HeritageLocation>> getLocations();
  Future<List<Artifact>> getArtifacts();
  Future<Artifact?> getArtifactById(String id);
  Future<bool> login(String email, String password);
}

class AppApiService implements ApiService {
  final bool useMock;
  final String baseUrl;

  AppApiService({
    this.useMock = true,
    this.baseUrl = 'https://api.smartheritage.vn/v1',
  });

  @override
  Future<List<HeritageLocation>> getLocations() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return mockLocations;
    }
    // Khi có API thật, chỉ cần mở comment dòng dưới:
    // final response = await http.get(Uri.parse('$baseUrl/locations'));
    // return (jsonDecode(response.body) as List).map((e) => HeritageLocation.fromJson(e)).toList();
    throw UnimplementedError('Chưa cấu hình API thật');
  }

  @override
  Future<List<Artifact>> getArtifacts() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return sampleArtifacts;
    }
    throw UnimplementedError('Chưa cấu hình API thật');
  }

  @override
  Future<Artifact?> getArtifactById(String id) async {
    final list = await getArtifacts();
    try {
      return list.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email == 'admin@gmail.com' && password == '123456') {
      return true;
    }
    return false;
  }
}
