import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../core/secure_http_client.dart';

class QuranDownloadService extends ChangeNotifier {
  final Dio _dio = SecureHttpClient.createTrustedClient('api.alquran.cloud');
  final Dio _audioDio = Dio(); // Separate client for audio downloads
  final Map<int, double> _downloadProgress = {};
  final Set<int> _downloadingSurahs = {};
  final Map<int, String> _downloadErrors = {};
  final Map<int, double> _audioDownloadProgress = {};
  final Set<int> _downloadingAudio = {};

  double? getProgress(int surahNumber) => _downloadProgress[surahNumber];
  bool isDownloading(int surahNumber) =>
      _downloadingSurahs.contains(surahNumber);
  String? getDownloadError(int surahNumber) => _downloadErrors[surahNumber];
  
  // Audio download getters
  double? getAudioProgress(int surahNumber) => _audioDownloadProgress[surahNumber];
  bool isDownloadingAudio(int surahNumber) =>
      _downloadingAudio.contains(surahNumber);
  
  void clearDownloadError(int surahNumber) {
    _downloadErrors.remove(surahNumber);
    notifyListeners();
  }

  // Initialize audio cache directory
  Future<void> initializeAudioCache() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/quran_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
  }

  Future<String> _getSurahPath(int surahNumber, String edition) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/quran/$edition/$surahNumber';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<bool> isSurahDownloaded(int surahNumber, String edition) async {
    final path = await _getSurahPath(surahNumber, edition);
    final file = File('$path/data.json');
    return await file.exists();
  }

  Future<void> downloadSurah(int surahNumber, String edition) async {
    if (_downloadingSurahs.contains(surahNumber)) return;

    _downloadingSurahs.add(surahNumber);
    _downloadProgress[surahNumber] = 0.0;
    notifyListeners();

    try {
      final path = await _getSurahPath(surahNumber, edition);

      // 1. Download JSON data
      final url =
          'https://api.alquran.cloud/v1/surah/$surahNumber/editions/quran-uthmani,$edition,ar.alafasy';
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final file = File('$path/data.json');
        // Dio's response.data is the parsed body
        await file.writeAsString(json.encode(response.data));
      }

      _downloadProgress[surahNumber] = 1.0;
    } catch (e) {
      debugPrint('Error downloading surah: $e');
      _downloadErrors[surahNumber] = 'Download failed: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}';
    } finally {
      _downloadingSurahs.remove(surahNumber);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getOfflineSurah(
      int surahNumber, String edition) async {
    try {
      final path = await _getSurahPath(surahNumber, edition);
      final file = File('$path/data.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading offline surah: $e');
    }
    return null;
  }

  Future<void> deleteDownloadedSurah(int surahNumber, String edition) async {
    final path = await _getSurahPath(surahNumber, edition);
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    notifyListeners();
  }

  // Audio download methods
  Future<bool> isAudioCached(int surahNumber) async {
    try {
      final audioPath = await _getAudioPath(surahNumber);
      final file = File(audioPath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking audio cache: $e');
      return false;
    }
  }

  Future<void> downloadSurahAudio(int surahNumber) async {
    if (_downloadingAudio.contains(surahNumber)) return;
    
    try {
      _downloadingAudio.add(surahNumber);
      _audioDownloadProgress[surahNumber] = 0.0;
      notifyListeners();

      final audioUrl = _getAudioUrl(surahNumber);
      final audioPath = await _getAudioPath(surahNumber);
      
      // Download with progress tracking
      await _audioDio.download(
        audioUrl,
        audioPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _audioDownloadProgress[surahNumber] = received / total;
            notifyListeners();
          }
        },
      );

      _audioDownloadProgress[surahNumber] = 1.0;
      debugPrint('✅ Audio downloaded for Surah $surahNumber');
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      String errorMessage = 'Download failed';
      
      // Provide user-friendly error messages
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'No internet connection';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout';
      } else if (e.toString().contains('storage') || e.toString().contains('space')) {
        errorMessage = 'Not enough storage space';
      }
      
      _downloadErrors[surahNumber] = errorMessage;
    } finally {
      _downloadingAudio.remove(surahNumber);
      notifyListeners();
    }
  }

  String _getAudioUrl(int surahNumber) {
    // Format surah number with leading zeros if needed
    final formattedNumber = surahNumber.toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$formattedNumber.mp3';
  }

  Future<String> _getAudioPath(int surahNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    final formattedNumber = surahNumber.toString().padLeft(3, '0');
    return '${directory.path}/quran_audio/$formattedNumber.mp3';
  }

  Future<String?> getCachedAudioPath(int surahNumber) async {
    try {
      final audioPath = await _getAudioPath(surahNumber);
      final file = File(audioPath);
      if (await file.exists()) {
        return audioPath;
      }
    } catch (e) {
      debugPrint('Error getting cached audio path: $e');
    }
    return null;
  }

  Future<void> deleteCachedAudio(int surahNumber) async {
    try {
      final audioPath = await _getAudioPath(surahNumber);
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted cached audio for Surah $surahNumber');
      }
    } catch (e) {
      debugPrint('Error deleting cached audio: $e');
    }
  }

  // Get total cached audio size
  Future<int> getCachedAudioSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/quran_audio');
      if (!await audioDir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in audioDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cached audio size: $e');
      return 0;
    }
  }
}
