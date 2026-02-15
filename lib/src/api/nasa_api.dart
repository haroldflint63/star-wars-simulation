import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// NASA API Service
///
/// Free NASA APIs:
/// - APOD: Astronomy Picture of the Day
/// - Mars Rover Photos
/// - EPIC: Earth images
/// - No API key required for demo usage
class NasaApi {
  static const String _apodUrl = 'https://api.nasa.gov/planetary/apod';
  static const String _marsRoverUrl =
      'https://api.nasa.gov/mars-photos/api/v1/rovers/curiosity/photos';
  static const String _apiKey = 'DEMO_KEY'; // Free demo key, 30 requests/hour

  /// Get Astronomy Picture of the Day
  static Future<ApodData?> getApod() async {
    try {
      final response = await http.get(Uri.parse('$_apodUrl?api_key=$_apiKey'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApodData.fromJson(data);
      }
    } catch (e) {
      debugPrint('NASA APOD API error: $e');
    }
    return null;
  }

  /// Get Mars Rover photos
  static Future<List<MarsPhoto>> getMarsPhotos({int sol = 1000}) async {
    try {
      final response = await http.get(
        Uri.parse('$_marsRoverUrl?sol=$sol&api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final photos = data['photos'] as List;
        return photos.take(5).map((p) => MarsPhoto.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('NASA Mars API error: $e');
    }
    return [];
  }

  /// Get random space background URL
  static Future<String?> getSpaceBackground() async {
    final apod = await getApod();
    if (apod != null && apod.mediaType == 'image') {
      return apod.url;
    }

    // Fallback to Mars photos
    final marsPhotos = await getMarsPhotos(sol: 1000 + DateTime.now().day);
    if (marsPhotos.isNotEmpty) {
      return marsPhotos.first.imgSrc;
    }

    return null;
  }
}

/// Astronomy Picture of the Day data
class ApodData {
  final String title;
  final String explanation;
  final String url;
  final String mediaType;
  final String date;

  ApodData({
    required this.title,
    required this.explanation,
    required this.url,
    required this.mediaType,
    required this.date,
  });

  factory ApodData.fromJson(Map<String, dynamic> json) {
    return ApodData(
      title: json['title'] ?? '',
      explanation: json['explanation'] ?? '',
      url: json['url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      date: json['date'] ?? '',
    );
  }
}

/// Mars Rover Photo data
class MarsPhoto {
  final int id;
  final String imgSrc;
  final String earthDate;
  final String cameraName;

  MarsPhoto({
    required this.id,
    required this.imgSrc,
    required this.earthDate,
    required this.cameraName,
  });

  factory MarsPhoto.fromJson(Map<String, dynamic> json) {
    return MarsPhoto(
      id: json['id'] ?? 0,
      imgSrc: json['img_src'] ?? '',
      earthDate: json['earth_date'] ?? '',
      cameraName: json['camera']?['full_name'] ?? 'Unknown',
    );
  }
}
