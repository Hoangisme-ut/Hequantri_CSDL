typedef HeritageArtifact = Artifact;

class Artifact {
  final String id;
  final String titleVi;
  final String titleEn;
  final String period;
  final String category;
  final String location;
  final String descriptionVi;
  final String descriptionEn;
  final String imageUrl;
  final bool isFavorite;
  final String? viewTime;
  final String icon;
  final int accent;

  const Artifact({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.period,
    required this.category,
    required this.location,
    required this.descriptionVi,
    required this.descriptionEn,
    required this.imageUrl,
    this.isFavorite = false,
    this.viewTime,
    this.icon = 'drum',
    this.accent = 0xFF1E2A5A,
  });

  String get title => titleVi;
  String get description => descriptionVi;

  String getTitle([String lang = 'vi']) => lang == 'en' ? titleEn : titleVi;
  String getDescription([String lang = 'vi']) =>
      lang == 'en' ? descriptionEn : descriptionVi;
}

class ArtifactCatalog {
  final List<Artifact> items;
  ArtifactCatalog({List<Artifact>? items}) : items = items ?? sampleArtifacts;
  void dispose() {}
}

final List<Artifact> sampleArtifacts = [
  const Artifact(
    id: '1',
    titleVi: 'Bia Tiến sĩ thời Lê - Mạc',
    titleEn: 'Doctoral Stelae of Le-Mac Dynasties',
    period: 'Thời Lê - Mạc (1442 - 1779)',
    category: 'Văn hóa',
    location: 'Văn Miếu - Quốc Tử Giám',
    descriptionVi: '82 tấm bia tiến sĩ tại Văn Miếu - Quốc Tử Giám là Di sản tư liệu thế giới vinh danh các bậc trí thức khoa bảng đạt học vị Tiến sĩ.',
    descriptionEn: '82 Doctoral stelae at Temple of Literature honoring royal exam graduates.',
    imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?q=80&w=600',
    isFavorite: true,
    viewTime: '12/04/2025 - 10:24',
    icon: 'vase',
  ),
  const Artifact(
    id: '2',
    titleVi: 'Bình gốm hoa lam',
    titleEn: 'Blue and White Ceramic Vase',
    period: 'Thời Lê (1428 - 1789)',
    category: 'Đồ gốm',
    location: 'Văn Miếu - Quốc Tử Giám',
    descriptionVi: 'Bình gốm hoa lam quý giá thể hiện kỹ thuật gốm sứ tinh xảo của người Việt thời Lê.',
    descriptionEn: 'Sophisticated blue and white ceramic vase reflecting pottery craftsmanship.',
    imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?q=80&w=600',
    isFavorite: true,
    viewTime: '11/04/2025 - 08:30',
    icon: 'vase',
  ),
  const Artifact(
    id: '3',
    titleVi: 'Kiếm ngắn thời Lý',
    titleEn: 'Ly Dynasty Short Sword',
    period: 'Thế kỷ XI - XII',
    category: 'Kim loại',
    location: 'Bảo tàng Hoàng thành Thăng Long',
    descriptionVi: 'Vũ khí cận chiến độc đáo thời Lý với chuôi đúc đồng chạm khắc hoa văn rồng tinh xảo.',
    descriptionEn:
        'A unique melee weapon of the Ly Dynasty with a bronze hilt.',
    imageUrl: 'https://images.unsplash.com/photo-1569429593410-b498b3fb3387?q=80&w=600',
    isFavorite: true,
    viewTime: '06/04/2025 - 09:15',
    icon: 'bell',
  ),
  const Artifact(
    id: '4',
    titleVi: 'Trống đồng Đông Sơn',
    titleEn: 'Dong Son Bronze Drum',
    period: 'Thời kỳ đồ đồng',
    category: 'Kim loại',
    location: 'Quần thể Cố đô Huế',
    descriptionVi: 'Biểu tượng văn hóa đại diện cho nền văn minh sông Hồng thời kỳ đồ đồng rực rỡ.',
    descriptionEn: 'Cultural symbol representing the peak of the Bronze Age Red River civilization.',
    imageUrl: 'https://images.unsplash.com/photo-1599707367072-cd6ada2bc375?q=80&w=600',
    isFavorite: true,
    viewTime: '08/04/2025 - 14:20',
    icon: 'drum',
  ),
];
