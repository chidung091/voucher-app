import '../models/voucher.dart';

class VoucherRepository {
  VoucherRepository();

  Future<List<Voucher>> fetchVouchers() async {
    return [
      Voucher(
        id: 1,
        title: 'FaceWashFox-Ưu đãi 117K cho Combo',
        subtitle: 'Sạch sâu & Cấp ẩm',
        priceVnd: 117000,
        points: 50,
        validUntil: DateTime(2026, 3, 31, 23, 59, 59),
        description:
            'Voucher giảm 117,000 VND cho khách hàng trải nghiệm Combo: Sạch sâu & Cấp ẩm. Đổi ngay 50 điểm thưởng để nhận được ưu đãi đặc biệt.',
        imageAsset: 'assets/images/sample.jpg',
        imageAssets: [
          'assets/images/sample.jpg',
          'assets/images/sampleB.jpg',
        ],
        isRedeemed: false,
      ),
      Voucher(
        id: 2,
        title: 'Weekend Cinema',
        subtitle: 'Combo bắp nước',
        priceVnd: 120000,
        points: 40,
        validUntil: DateTime(2026, 1, 15, 23, 59, 59),
        description:
            'Voucher giảm giá combo bắp nước tại rạp. Áp dụng cho các suất chiếu cuối tuần.',
        imageAsset: 'assets/images/sample.jpg',
        imageAssets: [
          'assets/images/sample.jpg',
          'assets/images/sampleB.jpg',
        ],
        isRedeemed: true,
      ),
      Voucher(
        id: 3,
        title: 'Ride Share',
        subtitle: 'Di chuyển an toàn',
        priceVnd: 75000,
        points: 30,
        validUntil: DateTime(2025, 12, 20, 23, 59, 59),
        description:
            'Giảm giá cho chuyến đi nội thành. Áp dụng trong giờ thấp điểm.',
        imageAsset: 'assets/images/sample.jpg',
        imageAssets: [
          'assets/images/sample.jpg',
          'assets/images/sampleB.jpg',
        ],
        isRedeemed: false,
      ),
      Voucher(
        id: 4,
        title: 'Grocery Saver',
        subtitle: 'Siêu thị gần nhà',
        priceVnd: 90000,
        points: 35,
        validUntil: DateTime(2026, 2, 10, 23, 59, 59),
        description:
            'Tiết kiệm cho giỏ hàng thiết yếu. Áp dụng cho hóa đơn từ 300,000 VND.',
        imageAsset: 'assets/images/sample.jpg',
        imageAssets: [
          'assets/images/sample.jpg',
          'assets/images/sampleB.jpg',
        ],
        isRedeemed: false,
      ),
      Voucher(
        id: 5,
        title: 'Spa Recharge',
        subtitle: 'Thư giãn cuối tuần',
        priceVnd: 180000,
        points: 80,
        validUntil: DateTime(2026, 5, 2, 23, 59, 59),
        description:
            'Giảm giá gói spa thư giãn. Đặt lịch trước tối thiểu 24 giờ.',
        imageAsset: 'assets/images/sample.jpg',
        imageAssets: [
          'assets/images/sample.jpg',
          'assets/images/sampleB.jpg',
        ],
        isRedeemed: true,
      ),
    ];
  }
}
