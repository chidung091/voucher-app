import '../models/voucher.dart';

class VoucherRepository {
  VoucherRepository();

  Future<List<Voucher>> fetchVouchers() async {
    return const [
      Voucher(
        id: 1,
        title: 'Cafeteria Combo',
        priceVnd: 45000,
        imageAsset: 'assets/images/logo.png',
        isRedeemed: false,
      ),
      Voucher(
        id: 2,
        title: 'Weekend Cinema',
        priceVnd: 120000,
        imageAsset: 'assets/images/logo.png',
        isRedeemed: true,
      ),
      Voucher(
        id: 3,
        title: 'Ride Share',
        priceVnd: 75000,
        imageAsset: 'assets/images/logo.png',
        isRedeemed: false,
      ),
      Voucher(
        id: 4,
        title: 'Grocery Saver',
        priceVnd: 90000,
        imageAsset: 'assets/images/logo.png',
        isRedeemed: false,
      ),
      Voucher(
        id: 5,
        title: 'Spa Recharge',
        priceVnd: 180000,
        imageAsset: 'assets/images/logo.png',
        isRedeemed: true,
      ),
    ];
  }
}
