class Voucher {
  const Voucher({
    required this.id,
    required this.title,
    required this.priceVnd,
    required this.imageAsset,
    required this.isRedeemed,
  });

  final int id;
  final String title;
  final int priceVnd;
  final String imageAsset;
  final bool isRedeemed;

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'] as int,
      title: json['title'] as String,
      priceVnd: json['priceVnd'] as int? ?? 0,
      imageAsset: json['imageAsset'] as String? ?? 'assets/images/logo.png',
      isRedeemed: json['completed'] as bool? ?? false,
    );
  }
}
