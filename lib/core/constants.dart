class AppConstants {
  static const int messageTtlHops = 7;
  static const int syncTtlHops = 0;

  static const String meshServiceUuid = "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C";
  static const String meshCharacteristicUuid =
      "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D";
  static const String meshDescriptorUuid =
      "00002902-0000-1000-8000-00805f9b34fb";

  static const int fragmentSizeThreshold = 512;

  // MTU negotiation settings
  static const bool requestMtu = true; // enabled for proper packet sizes
  static const int requestedMtuSize =
      247; // safer default, 517 sometimes fails on devices

  static const int maxFragmentSize = 469;

  static const int rekeyTimeLimitMs = 3600000; // 1 hour
  static const int maxPayloadSizeBytes = 256;
}
