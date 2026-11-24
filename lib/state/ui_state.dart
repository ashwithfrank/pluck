import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected bottom-nav tab (0 Download, 1 Queue, 2 Library, 3 Settings).
final tabProvider = StateProvider<int>((ref) => 0);

/// A URL pushed into the download screen (share intent, paste). Consumed once.
final incomingUrlProvider = StateProvider<String?>((ref) => null);
