import '../artifacts/artifact.dart';

class HeritageLocation {
  final String id;
  final String nameVi;
  final String nameEn;
  final String city;
  final String address;
  final String imageUrl;
  final double rating;
  final double latitude;
  final double longitude;
  final String descriptionVi;
  final String descriptionEn;

  const HeritageLocation({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.city,
    required this.address,
    required this.imageUrl,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.descriptionVi,
    required this.descriptionEn,
  });

  String getName(String lang) => lang == 'en' ? nameEn : nameVi;
  String getDescription(String lang) =>
      lang == 'en' ? descriptionEn : descriptionVi;
}

class HeritageRepository {
  Future<List<HeritageLocation>> fetchFeaturedLocations() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return mockLocations;
  }

  Future<List<Artifact>> fetchArtifacts() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return sampleArtifacts;
  }
}

final List<HeritageLocation> mockLocations = [
  const HeritageLocation(
    id: 'loc_1',
    nameVi: 'Văn Miếu - Quốc Tử Giám',
    nameEn: 'Temple of Literature',
    city: 'Hà Nội',
    address: '58 Quốc Tử Giám, Văn Miếu, Đống Đa, Hà Nội',
    imageUrl: 'assets/images/van_mieu_welcome.jpg',
    rating: 4.9,
    latitude: 21.0293,
    longitude: 105.8360,
    descriptionVi: 'Văn Miếu - Quốc Tử Giám là quần thể di tích lịch sử và là trường đại học đầu tiên của Việt Nam.',
    descriptionEn: 'The Temple of Literature hosted the Imperial Academy, Vietnam\'s first national university.',
  ),
  const HeritageLocation(
    id: 'loc_2',
    nameVi: 'Phố cổ Hội An',
    nameEn: 'Hoi An Ancient Town',
    city: 'Quảng Nam',
    address: 'Thành phố Hội An, Tỉnh Quảng Nam',
    imageUrl: 'assets/images/hoi_an_welcome.jpg',
    rating: 4.9,
    latitude: 15.8801,
    longitude: 108.3380,
    descriptionVi: 'Phố cổ Hội An là thương cảng cổ sầm uất ven sông Thu Bồn, di sản văn hóa thế giới được UNESCO công nhận.',
    descriptionEn: 'Hoi An Ancient Town is an exceptionally well-preserved example of a South-East Asian trading port.',
  ),
  const HeritageLocation(
    id: 'loc_3',
    nameVi: 'Quần thể Cố đô Huế',
    nameEn: 'Complex of Hue Monuments',
    city: 'Thừa Thiên Huế',
    address: 'Thành phố Huế, Tỉnh Thừa Thiên Huế',
    imageUrl: 'assets/images/hue_welcome.jpg',
    rating: 4.8,
    latitude: 16.4697,
    longitude: 107.5786,
    descriptionVi: 'Quần thể di tích Cố đô Huế là kinh đô cổ kính của triều đại nhà Nguyễn với hệ thống cung điện nguy nga.',
    descriptionEn: 'The Complex of Hue Monuments is a UNESCO World Heritage site located in central Vietnam.',
  ),
];
