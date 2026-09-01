import 'dart:async';

import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/navigation/external_redirect.dart';
import 'package:linkso_client/src/features/advertising_link/data/advertising_link_service.dart';
import 'package:material_ui/material_ui.dart';

class const AdvertisingLinkPage({
  required final String slug,
  required final LinkSoApiClient apiClient,
  final ExternalRedirect redirect = redirectToExternalUri,
  super.key,
}) extends StatefulWidget {
  @override
  State<AdvertisingLinkPage> createState() => _AdvertisingLinkPageState();
}

class _AdvertisingLinkPageState() extends State<AdvertisingLinkPage> {
  late final AdvertisingLinkService _service;
  AdvertisingSession? _session;
  AdvertisingTicket? _ticket;
  Timer? _timer;
  bool _loading = true;
  bool _confirming = false;
  int _remainingSeconds = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = AdvertisingLinkService(apiClient: widget.apiClient);
    unawaited(_start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('advertising-link-page'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _loading ? _buildLoading(context) : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: context.localizations.advertisingSessionLoading,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.localizations.advertisingSessionLoading),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final AdvertisingSession? session = _session;
    if (session == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.localizations.advertisingUnavailableTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(_error ?? context.localizations.advertisingUnavailableMessage),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('advertising-retry-button'),
            onPressed: _start,
            child: Text(context.localizations.tryAgainAction),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.localizations.advertisingSponsoredLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        if (session.campaign case final AdvertisingCampaign campaign) ...[
          if (campaign.imageUri case final Uri imageUri) ...[
            Semantics(
              image: true,
              label: context.localizations.advertisingImageLabel,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(campaign.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(campaign.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(campaign.advertiserUri.host, style: Theme.of(context).textTheme.bodySmall),
        ] else ...[
          Icon(Icons.ads_click_rounded, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            context.localizations.advertisingPlaceholderTitle,
            key: const ValueKey<String>('advertising-placeholder'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
        const SizedBox(height: 28),
        if (_ticket case final AdvertisingTicket ticket)
          FilledButton.icon(
            key: const ValueKey<String>('advertising-continue-button'),
            onPressed: () => widget.redirect(ticket.redirectUri),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.localizations.advertisingContinueAction),
          )
        else
          Semantics(
            liveRegion: true,
            label: _confirming
                ? context.localizations.advertisingConfirming
                : context.localizations.advertisingCountdown(_remainingSeconds),
            child: Row(
              key: const ValueKey<String>('advertising-countdown'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_confirming) ...[const CircularProgressIndicator(), const SizedBox(width: 16)],
                Flexible(
                  child: Text(
                    _confirming
                        ? context.localizations.advertisingConfirming
                        : context.localizations.advertisingCountdown(_remainingSeconds),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ],
    );
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _session = null;
      _ticket = null;
      _error = null;
    });
    try {
      final AdvertisingSession session = await _service.start(widget.slug);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _loading = false;
      });
      _startCountdown(_secondsUntil(session.unlocksAt));
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = switch (error.code) {
            'network_error' => context.localizations.networkError,
            'request_timeout' => context.localizations.requestTimeoutError,
            _ => context.localizations.advertisingUnavailableMessage,
          };
        });
      }
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _remainingSeconds = seconds);
    if (seconds == 0) {
      unawaited(_confirmReady());
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        unawaited(_confirmReady());
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _confirmReady() async {
    final AdvertisingSession? session = _session;
    if (session == null || _confirming || _ticket != null) {
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final AdvertisingTicket ticket = await _service.continueSession(slug: widget.slug, sessionId: session.id);
      if (mounted) {
        setState(() => _ticket = ticket);
      }
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'advertising_timer_not_finished') {
        _startCountdown(error.retryAfterSeconds ?? 1);
      } else if (error.statusCode == 404 || error.statusCode == 410) {
        setState(() {
          _session = null;
          _error = context.localizations.advertisingSessionExpired;
        });
      } else {
        setState(() {
          _error = switch (error.code) {
            'network_error' => context.localizations.networkError,
            'request_timeout' => context.localizations.requestTimeoutError,
            _ => context.localizations.unexpectedError,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  int _secondsUntil(DateTime unlocksAt) {
    final int milliseconds = unlocksAt.toUtc().difference(DateTime.now().toUtc()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }
}
