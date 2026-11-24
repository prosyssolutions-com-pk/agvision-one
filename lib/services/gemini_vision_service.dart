import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class GeminiVisionService {
  static const String _apiKey = 'GEMINI_API_KEY';

  static Future<Map<String, dynamic>> analyzeProduce(File imageFile) async {
    // 1. Compress to ~15 KB so the network upload completes in ~1 second
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 320,
      minHeight: 320,
      quality: 65,
    );

    final bytes = compressedBytes ?? await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final models = ['gemini-3.5-flash-lite', 'gemini-3.8-flash'];

    const prompt = '''
You are a strict commercial agricultural quality-control inspector for AgVision.
Inspect this image carefully using strict export standards:
1. Identify the fruit or vegetable (e.g., "Potato", "Garlic", "Tomato", "Onion"). If the image is NOT produce or is too blurry to inspect, set "produce_name" to "Not Produce" or "Blurry Scan".
2. Apply strict grading rules:
   - "Grade A": Premium export quality ONLY—perfect shape, zero blemishes, zero sprouts, zero cracks, and crisp focus (texture_score 90.0 - 100.0).
   - "Grade B": Minor surface dirt, small scratches, uneven shape, slight dryness, or minor skin cracks (texture_score 70.0 - 89.9).
   - "Reject": Visible rot, mold, dark bruises, sprouting, severe damage, blurry photo, or Not Produce (texture_score below 70.0).
3. Also provide a short 5-word "defect_notes" explaining why it received that grade.

Respond ONLY with valid JSON:
{
  "produce_name": "Garlic",
  "grade_rating": "Grade B",
  "texture_score": 81.5
}
''';

    String lastError = 'AI service unavailable';

    for (final model in models) {
      final url = Uri.https(
        'generativelanguage' + '.googleapis.com',
        '/v1beta/models/$model:generateContent',
        {'key': _apiKey},
      );

      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inline_data': {
                          'mime_type': 'image/jpeg',
                          'data': base64Image,
                        },
                      },
                    ],
                  },
                ],
                'generationConfig': {'responseMimeType': 'application/json'},
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final candidate = (decoded['candidates'] as List).first;
          final part = (candidate['content']['parts'] as List).first;
          final String jsonText = part['text'];
          return jsonDecode(jsonText) as Map<String, dynamic>;
        } else {
          lastError = 'Model $model (${response.statusCode}): ${response.body}';
          if (response.statusCode == 404 || response.statusCode == 503) {
            continue;
          }
          throw Exception(lastError);
        }
      } on Exception catch (e) {
        lastError = e.toString();
        if (model == models.last) {
          throw Exception(lastError);
        }
      }
    }

    throw Exception(lastError);
  }
}
