import 'package:flutter/services.dart';

/// The name of the channel shared with ios/Runner/AlarmBridge.swift. A test checks it.
const String signatureChannelName = 'app.catclock/signature';

/// When the signature that lets this app run on the iPhone expires. An app installed with
/// a free Apple ID stops opening after 7 days unless it is renewed.
abstract interface class SignatureInfo {
  /// The expiry time, or null if it cannot be found.
  Future<DateTime?> expiresAt();
}

class MethodChannelSignatureInfo implements SignatureInfo {
  MethodChannelSignatureInfo([this._channel = const MethodChannel(signatureChannelName)]);

  final MethodChannel _channel;

  @override
  Future<DateTime?> expiresAt() async {
    try {
      final seconds = await _channel.invokeMethod<double>('expiresAt');
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true);
    } catch (_) {
      return null;
    }
  }
}

/// A line about the signature, ready to show.
class SignatureMessage {
  const SignatureMessage(this.text, {required this.warning});

  final String text;

  /// True when it is close to expiring and should stand out.
  final bool warning;
}

/// The "days left" line: nothing if the expiry is unknown, and a warning at 2 whole days
/// or fewer. Days are counted down, so "6 days left" never overstates.
SignatureMessage? signatureMessage(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return null;
  final remaining = expiresAt.difference(now);
  if (remaining <= Duration.zero) {
    return const SignatureMessage('Signature expired. Renew it with AltStore.', warning: true);
  }
  final days = remaining.inDays;
  if (days < 1) {
    return const SignatureMessage('Signature expires today. Renew it with AltStore.', warning: true);
  }
  if (days <= 2) {
    final unit = days == 1 ? 'day' : 'days';
    return SignatureMessage('Signature: $days $unit left. Renew it with AltStore soon.', warning: true);
  }
  return SignatureMessage('Signature: $days days left', warning: false);
}