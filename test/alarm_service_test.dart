import 'package:flutter_test/flutter_test.dart';
import 'package:cat_clock/alarm/alarm.dart';
import 'package:cat_clock/alarm/alarm_controller.dart';
import 'package:cat_clock/alarm/alarm_service.dart';
import 'package:cat_clock/alarm/alarm_store.dart';
import 'package:cat_clock/alarm/sound_catalog.dart';
import 'package:cat_clock/storage/text_storage.dart';

import 'helpers/alarm_fakes.dart';
import 'helpers/weather_fakes.dart';

/// 6:30 AM in UTC on the next morning, with the default harness start.
final start = DateTime.utc(2026, 11, 11, 20, 0);
final fire = DateTime.utc(2026, 11, 12, 6, 30);

class Rig {
  Rig._(this.service, this.player, this.ticker, this.clock, this.storage, this.offset);

  final AlarmService service;
  final FakeSoundPlayer player;
  final FakeTicker ticker;
  final FakeClock clock;
  final MemoryTextStorage storage;
  final List<Duration> offset; // one element, so tests can change the zone
  int rings = 0;

  static Future<Rig> create({Alarm? saved, bool startService = true}) async {
    final storage = MemoryTextStorage();
    if (saved != null) await AlarmStore(storage).save(saved);
    final player = FakeSoundPlayer();
    final ticker = FakeTicker();
    final clock = FakeClock(start);
    final offset = <Duration>[Duration.zero];
    late Rig rig;
    final service = await AlarmService.load(
      store: AlarmStore(storage),
      player: player,
      ticker: ticker,
      nowUtc: clock.call,
      offsetAt: (_) => offset.first,
      onRing: () => rig.rings++,
    );
    rig = Rig._(service, player, ticker, clock, storage, offset);
    if (startService) service.start();
    return rig;
  }

  /// Moves the clock to [time] and lets one second tick.
  Future<void> at(DateTime time) async {
    clock.now = time;
    ticker.tick();
    await pumpEventQueue();
  }

  Future<Alarm> saved() => AlarmStore(storage).load();
}

const sixThirty = Alarm(hour: 6, minute: 30, enabled: true, soundId: 'cat_bell', volumeLevel: 4);

void main() {
  group('starting', () {
    test('loads the saved alarm and arms it when it was on', () async {
      final rig = await Rig.create(saved: sixThirty);
      expect(rig.service.alarm, sixThirty);
      expect(rig.service.state, AlarmState.armed);
      expect(rig.service.fireAt, fire);
    });

    test('uses the default alarm, switched off, when nothing was saved', () async {
      final rig = await Rig.create();
      expect(rig.service.alarm, const Alarm());
      expect(rig.service.state, AlarmState.off);
    });

    test('starts the one-second clock check', () async {
      final rig = await Rig.create();
      expect(rig.ticker.running, isTrue);
    });

    test('starting twice does not start two checks', () async {
      final rig = await Rig.create();
      rig.service.start();
      rig.clock.now = fire;
      rig.ticker.tick();
      await pumpEventQueue();
      expect(rig.player.count('alarm:'), 0, reason: 'alarm is off');
    });
  });

  group('ringing', () {
    test('plays the chosen sound at the chosen volume when the time comes', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire.subtract(const Duration(seconds: 1)));
      expect(rig.player.alarmIsPlaying, isFalse);

      await rig.at(fire);
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.player.events, ['alarm:cat_bell:4']);
      expect(rig.rings, 1);
    });

    test('tells the app once, not every second', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      await rig.at(fire.add(const Duration(seconds: 1)));
      await rig.at(fire.add(const Duration(seconds: 2)));
      expect(rig.rings, 1);
      expect(rig.player.count('alarm:'), 1);
    });

    test('rings at once when the laptop wakes up within 10 minutes after the time', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire.add(const Duration(minutes: 9)));
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.player.alarmIsPlaying, isTrue);
    });

    test('a wake-up more than 10 minutes late is a missed alarm, with no sound', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire.add(const Duration(hours: 2)));
      expect(rig.service.state, AlarmState.missed);
      expect(rig.service.missedAt, fire);
      expect(rig.player.count('alarm:'), 0);
      expect(rig.rings, 0);
    });

    test('stop silences the sound and turns a one-time alarm off', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.player.alarmIsPlaying, isFalse);
      expect(rig.service.state, AlarmState.off);
      expect((await rig.saved()).enabled, isFalse);
    });

    test('snooze silences the sound, and it plays again 9 minutes later', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      rig.service.snooze();
      await pumpEventQueue();
      expect(rig.player.alarmIsPlaying, isFalse);
      expect(rig.service.state, AlarmState.snoozed);

      await rig.at(fire.add(const Duration(minutes: 9)));
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.player.alarmIsPlaying, isTrue);
      expect(rig.player.count('alarm:'), 2);
      expect(rig.rings, 2);
    });

    test('the sound stops when an unanswered alarm becomes missed after 10 minutes', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      await rig.at(fire.add(const Duration(minutes: 10)));
      expect(rig.service.state, AlarmState.missed);
      expect(rig.player.alarmIsPlaying, isFalse);
    });

    test('a daily alarm goes back to waiting after stop, and rings again tomorrow', () async {
      final rig = await Rig.create(saved: sixThirty.copyWith(repeatDaily: true));
      await rig.at(fire);
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.service.state, AlarmState.armed);
      expect(rig.service.fireAt, fire.add(const Duration(days: 1)));

      await rig.at(fire.add(const Duration(days: 1)));
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.player.count('alarm:'), 2);
    });

    test('turning the alarm off while it rings silences it', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      rig.service.setEnabled(false);
      await pumpEventQueue();
      expect(rig.player.alarmIsPlaying, isFalse);
      expect(rig.service.state, AlarmState.off);
    });
  });

  group('when the sound cannot play', () {
    test('the alarm still counts as ringing, and the problem is reported', () async {
      final rig = await Rig.create(saved: sixThirty);
      rig.player.failToPlayAlarm = true;
      await rig.at(fire);
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.service.soundProblem, isTrue);
      expect(rig.rings, 1, reason: 'the window still comes forward');
    });

    test('the problem clears when the next ring plays fine', () async {
      final rig = await Rig.create(saved: sixThirty);
      rig.player.failToPlayAlarm = true;
      await rig.at(fire);
      rig.service.snooze();
      rig.player.failToPlayAlarm = false;
      await rig.at(fire.add(const Duration(minutes: 9)));
      expect(rig.service.soundProblem, isFalse);
    });

    test('a player that will not stop does not break the alarm', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      rig.player.failToStop = true;
      rig.service.stop();
      await pumpEventQueue();
      expect(rig.service.state, AlarmState.off);
    });
  });

  group('changing the settings', () {
    test('turning the alarm on arms it and saves it', () async {
      final rig = await Rig.create();
      rig.service.setEnabled(true);
      await pumpEventQueue();
      expect(rig.service.state, AlarmState.armed);
      expect((await rig.saved()).enabled, isTrue);
    });

    test('a new time, sound, volume, and repeat are all saved', () async {
      final rig = await Rig.create();
      rig.service.update(const Alarm(
        hour: 22,
        minute: 15,
        enabled: true,
        repeatDaily: true,
        soundId: 'purr_rise',
        volumeLevel: 2,
      ));
      await pumpEventQueue();
      final saved = await rig.saved();
      expect(saved.hour, 22);
      expect(saved.minute, 15);
      expect(saved.repeatDaily, isTrue);
      expect(saved.soundId, 'purr_rise');
      expect(saved.volumeLevel, 2);
    });

    test('settings survive a restart', () async {
      final first = await Rig.create();
      first.service.update(sixThirty);
      await pumpEventQueue();
      final second = await AlarmService.load(
        store: AlarmStore(first.storage),
        player: FakeSoundPlayer(),
        ticker: FakeTicker(),
        nowUtc: first.clock.call,
        offsetAt: (_) => Duration.zero,
      );
      expect(second.alarm, sixThirty);
      expect(second.state, AlarmState.armed);
    });

    test('quiet ticks do not rewrite the saved file', () async {
      final rig = await Rig.create(saved: sixThirty);
      rig.storage.contents = 'sentinel';
      await rig.at(fire.subtract(const Duration(minutes: 5)));
      await rig.at(fire.subtract(const Duration(minutes: 4)));
      expect(rig.storage.contents, 'sentinel');
    });

    test('a failure to save does not stop the alarm', () async {
      final player = FakeSoundPlayer();
      final ticker = FakeTicker();
      final clock = FakeClock(start);
      final service = AlarmService(
        controller: AlarmController(alarm: sixThirty, nowUtc: clock.call, offsetAt: (_) => Duration.zero),
        store: AlarmStore(BrokenStorage()),
        player: player,
        ticker: ticker,
        nowUtc: clock.call,
        offsetAt: (_) => Duration.zero,
      )..start();
      service.update(sixThirty.copyWith(minute: 31));
      await pumpEventQueue();
      clock.now = DateTime.utc(2026, 11, 12, 6, 31);
      ticker.tick();
      await pumpEventQueue();
      expect(service.state, AlarmState.ringing);
    });

    test('listeners are told when the state changes', () async {
      final rig = await Rig.create(saved: sixThirty);
      var told = 0;
      rig.service.addListener(() => told++);
      await rig.at(fire);
      expect(told, greaterThan(0));
    });
  });

  group('previews', () {
    test('play a short sample of the chosen sound at the chosen volume', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.service.preview();
      expect(rig.player.events, ['preview:cat_bell:4']);
    });

    test('can try a different sound or volume before it is chosen', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.service.preview(sound: soundById('purr_rise'), level: 1);
      expect(rig.player.events, ['preview:purr_rise:1']);
    });

    test('are not played while the alarm is ringing', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      await rig.service.preview();
      expect(rig.player.count('preview:'), 0);
    });
  });

  group('clock changes', () {
    test('a time zone change moves the ring time', () async {
      final rig = await Rig.create(saved: sixThirty);
      expect(rig.service.fireAt, fire);
      rig.offset[0] = const Duration(hours: 1);
      await rig.at(start.add(const Duration(seconds: 1)));
      expect(rig.service.fireAt, DateTime.utc(2026, 11, 12, 5, 30));
    });

    test('waking from sleep a few minutes after the alarm time still rings it', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(start.add(const Duration(seconds: 1)));
      // The laptop sleeps through 6:30 and wakes at 6:35. One tick, hours after the last.
      await rig.at(fire.add(const Duration(minutes: 5)));
      expect(rig.service.state, AlarmState.ringing);
      expect(rig.player.alarmIsPlaying, isTrue);
    });

    test('waking from sleep long after the alarm time marks it missed, not pushed to tomorrow', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(start.add(const Duration(seconds: 1)));
      await rig.at(fire.add(const Duration(hours: 3)));
      expect(rig.service.state, AlarmState.missed);
      expect(rig.service.missedAt, fire);
    });

    test('waking from sleep before the alarm time leaves it waiting for the same moment', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(start.add(const Duration(hours: 6)));
      expect(rig.service.state, AlarmState.armed);
      expect(rig.service.fireAt, fire);
    });
  });

  group('cleaning up', () {
    test('dispose stops the clock check and the sound', () async {
      final rig = await Rig.create(saved: sixThirty);
      await rig.at(fire);
      rig.service.dispose();
      await pumpEventQueue();
      expect(rig.ticker.running, isFalse);
      expect(rig.player.alarmIsPlaying, isFalse);
    });
  });
}
