import 'package:dio/dio.dart';

/// Utility class for extracting meaningful error messages from DioException
class ErrorExtractor {
  /// Extracts server error message from DioException
  /// 
  /// Priority order:
  /// 1. Server response message (e.g., "Invalid email or password")
  /// 2. Server response error details
  /// 3. Generic Dio error message
  static String extractServerMessage(DioException e) {
    try {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      
      // Try to extract message from response data
      if (data is Map<String, dynamic>) {
        // Check for 'message' field first
        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        
        // Check for 'error' field
        final error = data['error']?.toString();
        if (error != null && error.isNotEmpty) {
          return error;
        }
        
        // Check for 'errors' array
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final firstError = errors.first;
          if (firstError is Map<String, dynamic>) {
            final errorMsg = firstError['msg']?.toString() ?? 
                           firstError['message']?.toString();
            if (errorMsg != null && errorMsg.isNotEmpty) {
              return errorMsg;
            }
          }
        }
        
        // Check for 'detail' field
        final detail = data['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
      }
      
      // If no specific message found, return generic message with status
      return 'Request failed${status != null ? ' (HTTP $status)' : ''}: ${e.message}';
    } catch (_) {
      return 'Request failed: ${e.message}';
    }
  }
  
  /// Extracts server error message with custom fallback
  static String extractServerMessageWithFallback(
    DioException e, 
    String fallbackMessage,
  ) {
    final extractedMessage = extractServerMessage(e);
    
    // If the extracted message is generic, use the fallback
    if (extractedMessage.contains('Request failed') || 
        extractedMessage.contains('Dio error')) {
      return fallbackMessage;
    }
    
    return extractedMessage;
  }
}
