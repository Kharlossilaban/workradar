import 'dart:async';
import 'package:flutter/material.dart';

/// SessionService handles automatic session timeout after user inactivity.
///
/// Features:
/// - Auto logout after 15 minutes of inactivity
/// - Warning dialog 1 minute before logout
/// - Activity tracking (tap, scroll, navigation)
/// - Integration with AuthProvider
class SessionService extends ChangeNotifier {
  static const Duration _sessionTimeout = Duration(minutes: 15);
  static const Duration _warningBefore = Duration(minutes: 1);

  Timer? _sessionTimer;
  Timer? _warningTimer;
  DateTime? _lastActivity;
  bool _isWarningShown = false;
  bool _isSessionExpired = false;

  // Callback functions
  VoidCallback? _onSessionExpired;
  VoidCallback? _onShowWarning;
  VoidCallback? _onDismissWarning;

  /// Initialize session service with callbacks
  void initialize({
    required VoidCallback onSessionExpired,
    required VoidCallback onShowWarning,
    VoidCallback? onDismissWarning,
  }) {
    _onSessionExpired = onSessionExpired;
    _onShowWarning = onShowWarning;
    _onDismissWarning = onDismissWarning;
    startSession();
  }

  /// Start or restart the session timer
  void startSession() {
    _cancelTimers();
    _lastActivity = DateTime.now();
    _isSessionExpired = false;
    _isWarningShown = false;

    // Set warning timer (14 minutes = 15 - 1 minute warning)
    final warningDuration = _sessionTimeout - _warningBefore;
    _warningTimer = Timer(warningDuration, _showWarning);

    // Set session expiry timer
    _sessionTimer = Timer(_sessionTimeout, _expireSession);

    notifyListeners();
  }

  /// Record user activity to reset the session timer
  void recordActivity() {
    if (_isSessionExpired) return;

    _lastActivity = DateTime.now();

    // If warning is shown, dismiss it and restart session
    if (_isWarningShown) {
      _isWarningShown = false;
      _onDismissWarning?.call();
    }

    // Restart timers
    startSession();
  }

  /// Show warning dialog before session expires
  void _showWarning() {
    if (_isSessionExpired) return;

    _isWarningShown = true;
    _onShowWarning?.call();
    notifyListeners();
  }

  /// Expire the session and trigger logout
  void _expireSession() {
    _isSessionExpired = true;
    _isWarningShown = false;
    _cancelTimers();
    _onSessionExpired?.call();
    notifyListeners();
  }

  /// Cancel all timers
  void _cancelTimers() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _sessionTimer = null;
    _warningTimer = null;
  }

  /// Extend session (user clicked "Continue" on warning dialog)
  void extendSession() {
    _isWarningShown = false;
    _onDismissWarning?.call();
    startSession();
  }

  /// Stop session tracking (e.g., when user logs out manually)
  void stopSession() {
    _cancelTimers();
    _lastActivity = null;
    _isSessionExpired = false;
    _isWarningShown = false;
    notifyListeners();
  }

  /// Get remaining time before session expires
  Duration? get remainingTime {
    if (_lastActivity == null || _isSessionExpired) return null;

    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = _sessionTimeout - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if warning is currently shown
  bool get isWarningShown => _isWarningShown;

  /// Check if session has expired
  bool get isSessionExpired => _isSessionExpired;

  /// Get last activity timestamp
  DateTime? get lastActivity => _lastActivity;

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

/// Widget that wraps the app to track user activity
class SessionActivityDetector extends StatelessWidget {
  final Widget child;
  final SessionService sessionService;

  const SessionActivityDetector({
    super.key,
    required this.child,
    required this.sessionService,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => sessionService.recordActivity(),
      onPanUpdate: (_) => sessionService.recordActivity(),
      onScaleUpdate: (_) => sessionService.recordActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          sessionService.recordActivity();
          return false;
        },
        child: child,
      ),
    );
  }
}

/// Dialog widget for session timeout warning
class SessionTimeoutWarningDialog extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onLogout;
  final Duration countdownFrom;

  const SessionTimeoutWarningDialog({
    super.key,
    required this.onContinue,
    required this.onLogout,
    this.countdownFrom = const Duration(minutes: 1),
  });

  @override
  State<SessionTimeoutWarningDialog> createState() =>
      _SessionTimeoutWarningDialogState();
}

class _SessionTimeoutWarningDialogState
    extends State<SessionTimeoutWarningDialog> {
  late Timer _countdownTimer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.countdownFrom.inSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        widget.onLogout();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.timer_outlined, color: Colors.orange[700], size: 28),
          const SizedBox(width: 12),
          const Text('Session Timeout'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sesi Anda akan berakhir dalam',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              _formatTime(_secondsRemaining),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _secondsRemaining <= 10
                    ? Colors.red[700]
                    : Colors.orange[700],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lanjutkan aktivitas untuk memperpanjang sesi Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onLogout,
          child: Text('Logout', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: widget.onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Lanjutkan'),
        ),
      ],
    );
  }
}
