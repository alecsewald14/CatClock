import 'dart:async';

import 'package:flutter/material.dart';

import 'cat_painter.dart';
import 'walk_cycle.dart';

/// The walking cat. It fills its box, which should have the shape of the cat sheet
/// (1000 by 900).
///
/// The cat steps in place at up to 24 pictures a second. It stands still when the phone's
/// or laptop's "reduce motion" setting is on, and it stops while the app is hidden or
/// minimized, so it uses no power then.
class CatView extends StatefulWidget {
  const CatView({super.key, this.animate = true, this.pose});

  /// Set to false to show a still cat.
  final bool animate;

  /// Optional: the pose to draw. If given, the animation writes into it, which lets tests
  /// look at every frame. Without it the view makes its own.
  final ValueNotifier<CatPose>? pose;

  @override
  State<CatView> createState() => _CatViewState();
}

class _CatViewState extends State<CatView> with WidgetsBindingObserver {
  late final ValueNotifier<CatPose> _ownPose = ValueNotifier<CatPose>(CatPose.standing);
  ValueNotifier<CatPose> get _pose => widget.pose ?? _ownPose;

  Timer? _timer;
  int _frame = 0;
  bool _reduceMotion = false;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(CatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _sync();
  }

  /// Starts or stops the stepping to match the current settings.
  void _sync() {
    final shouldRun = widget.animate && !_reduceMotion && _appVisible;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(
        Duration(microseconds: Duration.microsecondsPerSecond ~/ catFramesPerSecond),
        (_) => _step(),
      );
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _frame = 0;
      _pose.value = CatPose.standing;
    }
  }

  void _step() {
    _frame++;
    _pose.value = poseForFrame(_frame);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _ownPose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        key: const Key('cat'),
        painter: CatPainter(_pose),
        isComplex: true,
      ),
    );
  }
}
