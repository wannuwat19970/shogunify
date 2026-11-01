//states.dart
import 'package:flutter/material.dart';

class States extends ChangeNotifier {
  bool isShuffling = false;

  void toggleShuffle() {
    isShuffling = !isShuffling;
    notifyListeners();
  }
}
