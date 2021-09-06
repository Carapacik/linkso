import 'package:get/get.dart';
import 'package:intl/intl.dart';

class OverviewPageController extends GetxController {
  static OverviewPageController instance = Get.find();

  final List<ClicksPerDay> listForChart = [
    ClicksPerDay(_getMonthDayBefore(6), 3),
    ClicksPerDay(_getMonthDayBefore(5), 10),
    ClicksPerDay(_getMonthDayBefore(4), 40),
    ClicksPerDay(_getMonthDayBefore(3), 20),
    ClicksPerDay(_getMonthDayBefore(2), 14),
    ClicksPerDay("Yesterday", 3),
    ClicksPerDay("Today", 5),
  ];

  static String _getMonthDayBefore(int days) {
    return DateFormat('MMMd').format(DateTime.now().subtract(Duration(days: days)));
  }
}

class ClicksPerDay {
  final String day;
  final int count;

  ClicksPerDay(this.day, this.count);
}
