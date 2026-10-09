class NotificationItem {
  const NotificationItem({
    required this.title,
    required this.content,
    required this.time,
    this.isRead = false,
    this.publishedAt,
    this.detailContent,
    this.eventTime,
    this.location,
  });

  final String title;
  final String content;
  final String time;
  final bool isRead;
  final DateTime? publishedAt;
  final String? detailContent;
  final String? eventTime;
  final String? location;

  NotificationItem markAsRead() => NotificationItem(
    title: title,
    content: content,
    time: time,
    isRead: true,
    publishedAt: publishedAt,
    detailContent: detailContent,
    eventTime: eventTime,
    location: location,
  );
}

const mockNotifications = <NotificationItem>[
  NotificationItem(
    title: 'Lịch khám đã được xác nhận',
    content: 'Lịch khám Nội tổng quát của bạn đã được xác nhận. Vui lòng đến trước giờ hẹn 15 phút.',
    time: '10 phút trước',
  ),
  NotificationItem(
    title: 'Nhắc nhở lịch khám sắp tới',
    content: 'Bạn có lịch khám vào 08:30 ngày mai. Hãy mang theo giấy tờ tùy thân và hồ sơ sức khỏe.',
    time: '1 giờ trước',
  ),
  NotificationItem(
    title: 'Kết quả khám đã sẵn sàng',
    content: 'Kết quả khám của bạn đã được cập nhật. Bạn có thể xem lại trong hồ sơ sức khỏe.',
    time: '2 giờ trước',
  ),
  NotificationItem(
    title: 'Cập nhật lịch làm việc của bác sĩ',
    content: 'Lịch làm việc của bác sĩ đã được cập nhật. Vui lòng kiểm tra khi đặt lịch khám mới.',
    time: 'Hôm qua, 16:45',
    isRead: true,
  ),
  NotificationItem(
    title: 'Chào mừng bạn đến với HealWay',
    content: 'Đặt lịch khám và theo dõi sức khỏe thuận tiện hơn cùng HealWay.',
    time: 'Hôm qua, 09:00',
    isRead: true,
  ),
];
