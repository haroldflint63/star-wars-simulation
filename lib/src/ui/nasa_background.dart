import 'package:flutter/material.dart';
import '../api/nasa_api.dart';

/// NASA space background with live imagery
class NasaSpaceBackground extends StatefulWidget {
  const NasaSpaceBackground({super.key});

  @override
  State<NasaSpaceBackground> createState() => _NasaSpaceBackgroundState();
}

class _NasaSpaceBackgroundState extends State<NasaSpaceBackground> {
  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNasaImage();
  }

  Future<void> _loadNasaImage() async {
    try {
      final url = await NasaApi.getSpaceBackground();
      if (mounted) {
        setState(() {
          _imageUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load NASA image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageUrl == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 2.0,
            colors: [Color(0xFF0a1929), Color(0xFF051222), Colors.black],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // NASA image background
        Positioned.fill(
          child: Image.network(
            _imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 2.0,
                    colors: [
                      Color(0xFF0a1929),
                      Color(0xFF051222),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Dark overlay for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// NASA APOD Display Widget
class NasaApodDisplay extends StatefulWidget {
  const NasaApodDisplay({super.key});

  @override
  State<NasaApodDisplay> createState() => _NasaApodDisplayState();
}

class _NasaApodDisplayState extends State<NasaApodDisplay> {
  ApodData? _apod;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApod();
  }

  Future<void> _loadApod() async {
    final data = await NasaApi.getApod();
    if (mounted) {
      setState(() {
        _apod = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    if (_apod == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _apod!.title,
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _apod!.explanation,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'NASA APOD - ${_apod!.date}',
            style: TextStyle(
              color: Colors.cyan.withValues(alpha: 0.7),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
