class Voucher {
  const Voucher({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.priceVnd,
    required this.points,
    required this.validUntil,
    required this.description,
    required this.redemptionRules,
    required this.afterSales,
    required this.imageAsset,
    required this.imageAssets,
    required this.isRedeemed,
  });

  final int id;
  final String title;
  final String subtitle;
  final int priceVnd;
  final int points;
  final DateTime validUntil;
  final String description;
  final String redemptionRules;
  final String afterSales;
  final String imageAsset;
  final List<String> imageAssets;
  final bool isRedeemed;

  factory Voucher.fromJson(Map<String, dynamic> json) {
    final images = (json['imageAssets'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return Voucher(
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      priceVnd: json['priceVnd'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
      validUntil: DateTime.tryParse(json['validUntil'] as String? ?? '') ??
          DateTime.now(),
      description: json['description'] as String? ?? '',
      redemptionRules: json['redemptionRules'] as String? ?? '',
      afterSales: json['afterSales'] as String? ?? '',
      imageAsset: json['imageAsset'] as String? ?? 'assets/images/logo.png',
      imageAssets: images,
      isRedeemed: json['completed'] as bool? ?? false,
    );
  }
}
