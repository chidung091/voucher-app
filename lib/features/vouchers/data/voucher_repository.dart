import '../models/voucher.dart';

class VoucherRepository {
  VoucherRepository();

  Future<List<Voucher>> fetchVouchers() async {
    return [
      Voucher(
        id: 1,
        title: 'Grab - Mã giảm giá 50,000đ',
        subtitle: 'Di chuyển và ăn uống',
        priceVnd: 50000,
        points: 50,
        validUntil: DateTime(2026, 3, 31, 23, 59, 59),
        description:
            'Voucher giảm 50,000 VND cho khách hàng sử dụng các dịch vụ '
            'của Grab. Đổi ngay 50 điểm thưởng để nhận được voucher. '
            'Áp dụng cho các tất cả các dịch vụ trên ứng dụng Grab.\n',
        redemptionRules: 'Điều khoản & điều kiện:\n'
            '1. Thời hạn sử dụng: 01/10/2025 - 31/03/2026\n'
            '2. Mỗi E-voucher chỉ được sử dụng 01 lần và cho 1 đơn hàng.\n'
            '3. E-Voucher không thể quy đổi ra tiền mặt, không được hoàn trả hay bán lại.\n'
            '4. Không áp dụng đồng thời với các chương trình khuyến mãi khác.\n'
            '5. Khách hàng có trách nhiệm bảo mật thông tin mã thẻ. Nhà hàng sẽ không '
            'chịu trách nhiệm hoàn trả các mã thẻ bị mất hoặc ở trạng thái “đã sử dụng” '
            'với bất kỳ lý do gì.\n'
            '6. E-Voucher áp dụng tất cả các ngày trong tuần và áp dụng trên toàn quốc.\n'
            '7. Voucher được phát hành bởi Grab.\n'
            '8. Hình thức áp dụng: Trên toàn quốc\n\n'
            'Cách thức áp dụng:\n'
            'Bước 1: Khách hàng đưa mã code cho nhân viên hỗ trợ\n'
            'Bước 2: Nhân viên xác nhận, quét mã code và áp dụng chương trình ưu đãi\n'
            'Bước 3: Khách hàng tiến hành thanh toán',
        afterSales:
            'Hotline chăm sóc khách hàng: 1900.299.232 (từ 8h-22h hàng ngày, '
            'bao gồm lễ tết) để được hỗ trợ.',
        imageAsset: 'assets/images/sample.png',
        imageAssets: [
          'assets/images/sample.png',
        ],
        isRedeemed: false,
      ),
      Voucher(
        id: 2,
        title: 'Phúc Long - Mã giảm giá 50k',
        subtitle: 'Cafe và nhà hàng',
        priceVnd: 50000,
        points: 40,
        validUntil: DateTime(2026, 3, 31, 23, 59, 59),
        description:
            'Vui lòng xuất trình đường link nhận quà có chứa mã evoucher cho nhân viên tại quầy trước khi thanh toán để được áp dụng evoucher. Không chấp nhận đường link chụp qua màn hình điện thoại.',
        redemptionRules:
            'Đến trực tiếp tại các cơ sở, cửa hàng của Phúc Long để đổi quà.\n'
            'Hạn sử dụng của evoucher được hiển thị ở trên evoucher.\n'
            'E-voucher được áp dụng tại tất cả địa điểm kinh doanh của Phuc Long (trừ cửa hàng Phúc Long Takashimaya và Phúc Long Sân Bay Tân Sơn Nhất).\n'
            'evoucher không được sử dụng kết hợp với các chương trình quà tặng, khuyến mãi khác như cộng điểm, giảm giá.\n'
            'Áp dụng cho tất cả các ngày trong tuần, ngày lễ, ngày tết.\n'
            'Có thể sử dụng nhiều mã evoucher trên cùng 1 hoá đơn. evoucher sẽ không được hoàn lại tiền thừa và không có giá trị quy đổi thành tiền mặt.\n'
            'Cả Wogi và Phúc Long không chịu trách nhiệm trong trường hợp evoucher bị mất cắp, quá hạn sử dụng, đồng thời cũng không có nghĩa vụ thay thế hoặc đền bù giá trị cho chủ nhân của evoucher.\n'
            'Phúc Long có quyền từ chối nhận evoucher nếu bị coi là giả mạo hoặc hết hạn.\n'
            'Vui lòng xem thêm thông tin tại website của Phuc Long: phuclong.com.vn',
        afterSales:
            'Hotline chăm sóc khách hàng: 1900.299.232 (từ 8h-22h hàng ngày, '
            'bao gồm lễ tết) để được hỗ trợ.',
        imageAsset: 'assets/images/pltea.png',
        imageAssets: [
          'assets/images/pltea.png',
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
        redemptionRules:
            'Nhập mã trước khi đặt xe. Không áp dụng trong giờ cao điểm.',
        afterSales: 'Liên hệ tổng đài trong vòng 48h để được hỗ trợ hoàn tiền.',
        imageAsset: 'assets/images/sample.png',
        imageAssets: [
          'assets/images/sample.png',
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
        redemptionRules:
            'Áp dụng một lần trên hóa đơn đủ điều kiện. Không đổi tiền mặt.',
        afterSales:
            'Hoàn tiền theo chính sách siêu thị nếu phát sinh lỗi hệ thống.',
        imageAsset: 'assets/images/sample.png',
        imageAssets: [
          'assets/images/sample.png',
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
        redemptionRules:
            'Đặt lịch trước 24h. Không áp dụng cuối tuần hoặc ngày lễ.',
        afterSales: 'Được đổi lịch một lần nếu báo trước tối thiểu 12h.',
        imageAsset: 'assets/images/sample.png',
        imageAssets: [
          'assets/images/sample.png',
        ],
        isRedeemed: true,
      ),
    ];
  }
}
