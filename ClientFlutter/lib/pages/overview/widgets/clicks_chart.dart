import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:linkso/controllers/overview_page_controller.dart';

class ClicksChart extends StatelessWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;

  const ClicksChart(this.seriesList, {this.animate = false});

  factory ClicksChart.withRequestData(List<ClicksPerDay> data) {
    return ClicksChart(
      _createRequestData(data),
      animate: true,
    );
  }

  static List<charts.Series<ClicksPerDay, String>> _createRequestData(List<ClicksPerDay> data) {
    return [
      charts.Series<ClicksPerDay, String>(
        id: 'Clicks',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (ClicksPerDay clicks, _) => clicks.day,
        measureFn: (ClicksPerDay clicks, _) => clicks.count,
        data: data,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return charts.BarChart(
      seriesList,
      animate: animate,
    );
  }
}
