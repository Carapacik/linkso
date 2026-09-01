import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_models.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_service.dart';
import 'package:material_ui/material_ui.dart';

class const AnalyticsPage({required final AnalyticsDataSource service, final String? linkId, super.key})
    extends StatefulWidget {
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState() extends State<AnalyticsPage> {
  int _days = 30;
  AnalyticsReport? _report;
  ApiFailure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final AnalyticsReport report = widget.linkId == null
          ? await widget.service.dashboard(days: _days)
          : await widget.service.link(id: widget.linkId!, days: _days);
      if (mounted) {
        setState(() => _report = report);
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = failure);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnalyticsReport? report = _report;
    return Column(
      key: const ValueKey<String>('analytics-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                report?.link == null
                    ? context.localizations.analyticsTitle
                    : context.localizations.linkAnalyticsTitle(report!.link!.title ?? report.link!.slug),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: context.localizations.refreshAction,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(context.localizations.analyticsDescription),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<int>(
            key: const ValueKey<String>('analytics-period'),
            value: _days,
            items: const [
              7,
              30,
              90,
            ].map((days) => DropdownMenuItem(value: days, child: Text('$days'))).toList(growable: false),
            onChanged: _loading
                ? null
                : (days) {
                    if (days == null || days == _days) {
                      return;
                    }
                    setState(() => _days = days);
                    unawaited(_load());
                  },
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_failure != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(switch (_failure!.code) {
                    'network_error' => context.localizations.networkError,
                    'request_timeout' => context.localizations.requestTimeoutError,
                    _ => context.localizations.analyticsLoadError,
                  }),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(context.localizations.tryAgainAction)),
                ],
              ),
            ),
          )
        else if (report != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: context.localizations.analyticsLinks, value: report.summary.links),
              _MetricCard(label: context.localizations.analyticsHumanRedirects, value: report.summary.humanRedirects),
              _MetricCard(label: context.localizations.analyticsBotRedirects, value: report.summary.botRedirects),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.localizations.analyticsByDay, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _LegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        label: context.localizations.analyticsHumanRedirects,
                      ),
                      _LegendItem(
                        color: Theme.of(context).colorScheme.secondary,
                        label: context.localizations.analyticsBotRedirects,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DailyChart(series: report.series),
                  const SizedBox(height: 8),
                  Text(
                    '${MaterialLocalizations.of(context).formatShortDate(report.period.from)} — '
                    '${MaterialLocalizations.of(context).formatShortDate(report.period.to)}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(context.localizations.advertisingFunnelTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: context.localizations.advertisingImpressions, value: report.funnel.impressions),
              _MetricCard(
                label: context.localizations.advertisingTimerCompletions,
                value: report.funnel.timerCompletions,
              ),
              _MetricCard(label: context.localizations.advertisingRedirects, value: report.funnel.redirects),
            ],
          ),
        ],
      ],
    );
  }
}

class const _LegendItem({required final Color color, required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class const _MetricCard({required final String label, required final int value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    ),
  );
}

class const _DailyChart({required final List<DailyRedirects> series}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final int maximum = series.fold<int>(
      1,
      (value, item) => math.max(value, math.max(item.humanRedirects, item.botRedirects)),
    );
    return SizedBox(
      height: 180,
      child: LineChart(
        key: const ValueKey<String>('analytics-daily-chart'),
        LineChartData(
          minX: 0,
          maxX: math.max(1, series.length - 1).toDouble(),
          minY: 0,
          maxY: maximum.toDouble(),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(),
            rightTitles: AxisTitles(),
            bottomTitles: AxisTitles(),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      '${series[spot.x.toInt()].day.toIso8601String().substring(0, 10)}\n${spot.y.toInt()}',
                      Theme.of(context).textTheme.bodySmall!
                          .copyWith(color: Theme.of(context).colorScheme.onInverseSurface, fontWeight: FontWeight.w700),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          lineBarsData: [
            _line((item) => item.humanRedirects, Theme.of(context).colorScheme.primary),
            _line((item) => item.botRedirects, Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(int Function(DailyRedirects) value, Color color) => LineChartBarData(
    spots: [
      for (int index = 0; index < series.length; index++) FlSpot(index.toDouble(), value(series[index]).toDouble()),
    ],
    color: color,
    barWidth: 3,
    isCurved: series.length > 2,
    dotData: FlDotData(show: series.length <= 30),
    belowBarData: BarAreaData(),
  );
}
