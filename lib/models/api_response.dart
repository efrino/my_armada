class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;
  final List<String>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
    this.errors,
  });

  factory ApiResponse.success(T data, {String message = 'Berhasil'}) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
      statusCode: 200,
    );
  }

  factory ApiResponse.error(String message, {int? statusCode, List<String>? errors}) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }

  factory ApiResponse.networkError() {
    return ApiResponse(
      success: false,
      message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      statusCode: 0,
    );
  }

  factory ApiResponse.timeout() {
    return ApiResponse(
      success: false,
      message: 'Koneksi timeout. Server tidak merespons.',
      statusCode: 408,
    );
  }

  factory ApiResponse.serverError() {
    return ApiResponse(
      success: false,
      message: 'Terjadi kesalahan pada server.',
      statusCode: 500,
    );
  }
}