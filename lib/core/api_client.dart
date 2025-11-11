import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import 'supa_env.dart';

class ApiClient {
  final Dio _dio;
  ApiClient._(this._dio);

  static ApiClient create() {
    // Determina la baseUrl PostgREST in modo robusto:
    // 1) Preferisci SUPABASE_URL (compile-time via --dart-define)
    // 2) Fallback su API_BASE_URL da .env se disponibile
    final supaUrl = SupaEnv.url.trim();
    String baseUrl;
    if (supaUrl.isNotEmpty) {
      baseUrl = supaUrl.endsWith('/') ? '${supaUrl}rest/v1/' : '$supaUrl/rest/v1/';
    } else {
      // Evita eccezioni se dotenv non è inizializzato
      try {
        baseUrl = Env.apiBase; // es.: https://...supabase.co/rest/v1/
      } catch (_) {
        baseUrl = '';
      }
    }
    if (baseUrl.isEmpty) {
      throw StateError('Config mancante: imposta SUPABASE_URL via --dart-define oppure API_BASE_URL nel .env');
    }

    // Chiave anon per header apikey e fallback Authorization
    final anon = SupaEnv.anonKey.trim();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept-Profile': 'public',
      'Content-Profile': 'public',
      if (anon.isNotEmpty) 'apikey': anon,
    };

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: headers,
      validateStatus: (s) => s != null && s < 500,
    ));

    // Log richieste/risposte
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: false,
      responseBody: true,
      responseHeader: false,
    ));

    // Interceptor che mette il token GIUSTO (utente se presente, altrimenti anon)
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = Supabase.instance.client.auth.currentSession;
          final userToken = session?.accessToken;
          if (userToken != null && userToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $userToken';
          } else if (anon.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $anon';
          } else {
            options.headers.remove('Authorization');
          }
          return handler.next(options);
        },
      ),
    );

    return ApiClient._(dio);
  }

  Future<Response<List>> getList(String path, {Map<String, dynamic>? query}) =>
      _dio.get<List>(path, queryParameters: query);

  Future<Response<List>> insert(String path, {required List data}) =>
      _dio.post<List>(path, data: data);

  Future<Response<void>> delete(String path, {Map<String, dynamic>? query}) =>
      _dio.delete(path, queryParameters: query);

  // Ritorna il totale delle righe che soddisfano i filtri usando PostgREST
  // Estrae il valore dall'header Content-Range (richiede Prefer: count=exact)
  Future<int> count(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get<List>(
      path,
      queryParameters: {
        ...?query,
        // se non specificato dall'esterno, usiamo una colonna minima
        if (!(query?.containsKey('select') ?? false)) 'select': 'id',
      },
      options: Options(headers: {
        ..._dio.options.headers,
        'Prefer': 'count=exact',
        // riduce il payload al minimo; PostgREST restituirà comunque Content-Range
        'Range': '0-0',
      }),
    );

    final cr = res.headers.value('content-range');
    if (cr != null && cr.contains('/')) {
      final totalStr = cr.split('/').last.trim();
      final total = int.tryParse(totalStr);
      if (total != null) return total;
    }

    // Fallback: se manca l'header (es. proxy), usa la size del body
    final data = res.data;
    if (data is List) return data.length;
    return 0;
  }
}
