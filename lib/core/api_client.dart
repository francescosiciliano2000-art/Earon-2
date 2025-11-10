import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

class ApiClient {
  final Dio _dio;
  ApiClient._(this._dio);

  static ApiClient create() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept-Profile': 'public',
      'Content-Profile': 'public',
      // apikey serve sempre, anche con token utente
      if (Env.supabaseAnon != null) 'apikey': Env.supabaseAnon!,
    };

    final dio = Dio(BaseOptions(
      baseUrl: Env.apiBase, // es.: https://...supabase.co/rest/v1/
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
          } else if ((Env.supabaseAnon ?? '').isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${Env.supabaseAnon}';
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
