package com.asso.asso

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe exige que l'Activity hôte étende FlutterFragmentActivity
// (et non FlutterActivity) pour présenter la Payment Sheet native.
class MainActivity : FlutterFragmentActivity()
