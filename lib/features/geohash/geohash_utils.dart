import 'dart:math' as math;

/// Geohash encoding/decoding utilities for location-based channels.
/// Port of Android GeohashUtils for Flutter parity.
class GeohashUtils {
  static const String _base32Chars = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes a latitude/longitude pair into a geohash string.
  /// [precision] determines the length of the geohash (1-12).
  static String encode(double latitude, double longitude, {int precision = 6}) {
    if (precision < 1 || precision > 12) {
      throw ArgumentError('Precision must be between 1 and 12');
    }

    double minLat = -90.0;
    double maxLat = 90.0;
    double minLon = -180.0;
    double maxLon = 180.0;

    final buffer = StringBuffer();
    int bits = 0;
    int bitsTotal = 0;
    int hashValue = 0;
    bool isEven = true;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLon = mid;
        } else {
          hashValue = hashValue << 1;
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = hashValue << 1;
          maxLat = mid;
        }
      }

      isEven = !isEven;
      bitsTotal++;

      if (bitsTotal == 5) {
        buffer.write(_base32Chars[hashValue]);
        bitsTotal = 0;
        hashValue = 0;
      }
    }

    return buffer.toString();
  }

  /// Decodes a geohash string into latitude/longitude bounds.
  /// Returns [minLat, minLon, maxLat, maxLon].
  static List<double> decodeBounds(String geohash) {
    if (geohash.isEmpty) {
      throw ArgumentError('Geohash cannot be empty');
    }

    double minLat = -90.0;
    double maxLat = 90.0;
    double minLon = -180.0;
    double maxLon = 180.0;
    bool isEven = true;

    for (int i = 0; i < geohash.length; i++) {
      final c = geohash[i].toLowerCase();
      final idx = _base32Chars.indexOf(c);
      if (idx < 0) {
        throw ArgumentError('Invalid geohash character: $c');
      }

      for (int bit = 4; bit >= 0; bit--) {
        final bitValue = (idx >> bit) & 1;
        if (isEven) {
          final mid = (minLon + maxLon) / 2;
          if (bitValue == 1) {
            minLon = mid;
          } else {
            maxLon = mid;
          }
        } else {
          final mid = (minLat + maxLat) / 2;
          if (bitValue == 1) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }
        isEven = !isEven;
      }
    }

    return [minLat, minLon, maxLat, maxLon];
  }

  /// Decodes a geohash to its center point [latitude, longitude].
  static List<double> decodeCenter(String geohash) {
    final bounds = decodeBounds(geohash);
    final lat = (bounds[0] + bounds[2]) / 2;
    final lon = (bounds[1] + bounds[3]) / 2;
    return [lat, lon];
  }

  /// Validates a geohash string.
  static bool isValid(String geohash) {
    if (geohash.isEmpty || geohash.length > 12) return false;
    final allowed = _base32Chars.split('').toSet();
    return geohash.toLowerCase().split('').every((c) => allowed.contains(c));
  }

  /// Returns approximate coverage in meters for a geohash of given length.
  static double getCoverageMeters(int precision) {
    // Approximate max cell dimension at equator
    switch (precision) {
      case 1:
        return 5000000;
      case 2:
        return 1250000;
      case 3:
        return 156000;
      case 4:
        return 39100;
      case 5:
        return 4890;
      case 6:
        return 1220;
      case 7:
        return 153;
      case 8:
        return 38.2;
      case 9:
        return 4.77;
      case 10:
        return 1.19;
      case 11:
        return 0.149;
      case 12:
        return 0.037;
      default:
        return 5000000;
    }
  }

  /// Returns a human-readable coverage string.
  static String getCoverageString(int precision) {
    final meters = getCoverageMeters(precision);
    if (meters >= 1000) {
      final km = meters / 1000;
      if (km >= 100) {
        return '~${km.round()} km';
      } else if (km >= 10) {
        return '~${km.toStringAsFixed(0)} km';
      } else {
        return '~${km.toStringAsFixed(1)} km';
      }
    } else {
      return '~${meters.round()} m';
    }
  }
}

/// Geohash channel level for location-based messaging.
/// Matches Android GeohashChannelLevel enum.
enum GeohashChannelLevel {
  region(2, 'Region'),
  province(4, 'Province'),
  city(5, 'City'),
  neighborhood(6, 'Neighborhood'),
  block(7, 'Block'),
  building(8, 'Building');

  final int precision;
  final String displayName;

  const GeohashChannelLevel(this.precision, this.displayName);

  /// Gets the level for a given geohash length.
  static GeohashChannelLevel fromLength(int length) {
    switch (length) {
      case 1:
      case 2:
        return region;
      case 3:
      case 4:
        return province;
      case 5:
        return city;
      case 6:
        return neighborhood;
      case 7:
        return block;
      case 8:
      default:
        return building;
    }
  }
}

/// A geohash-based location channel.
/// Matches Android GeohashChannel class.
class GeohashChannel {
  final GeohashChannelLevel level;
  final String geohash;

  const GeohashChannel({
    required this.level,
    required this.geohash,
  });

  /// Creates a channel from coordinates at a given level.
  factory GeohashChannel.fromCoordinates(
    double latitude,
    double longitude,
    GeohashChannelLevel level,
  ) {
    final geohash = GeohashUtils.encode(
      latitude,
      longitude,
      precision: level.precision,
    );
    return GeohashChannel(level: level, geohash: geohash);
  }

  /// Gets the coverage string for this channel.
  String get coverageString => GeohashUtils.getCoverageString(geohash.length);

  /// Gets the center coordinates of this geohash.
  List<double> get center => GeohashUtils.decodeCenter(geohash);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeohashChannel &&
        other.level == level &&
        other.geohash == geohash;
  }

  @override
  int get hashCode => level.hashCode ^ geohash.hashCode;

  @override
  String toString() => 'GeohashChannel($level, #$geohash)';
}

/// Channel identifier for mesh or location channels.
/// Matches Android ChannelID sealed class.
abstract class ChannelId {
  const ChannelId();
}

/// Mesh (Bluetooth) channel identifier.
class MeshChannelId extends ChannelId {
  const MeshChannelId();

  @override
  bool operator ==(Object other) => other is MeshChannelId;

  @override
  int get hashCode => 'mesh'.hashCode;

  @override
  String toString() => 'ChannelId.Mesh';
}

/// Location (geohash) channel identifier.
class LocationChannelId extends ChannelId {
  final GeohashChannel channel;

  const LocationChannelId(this.channel);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationChannelId && other.channel == channel;
  }

  @override
  int get hashCode => channel.hashCode;

  @override
  String toString() => 'ChannelId.Location(${channel.geohash})';
}
