// lib/config/api_config.dart
// API Anahtarlarını Güvenli Şekilde Saklayın

class ApiConfig {
  // DeepSeek API Key
  // Ücretsiz API key almak için: https://platform.deepseek.com/
  // 1. Hesap oluşturun
  // 2. API Keys bölümüne gidin
  // 3. Yeni bir API key oluşturun
  // 4. Aşağıdaki değişkene yapıştırın
  
  static const String deepSeekApiKey = 'sk-afc69553685a48ab97d88522f3cdc2e5';
  static const String deepSeekApiUrl = 'https://api.deepseek.com/v1/chat/completions';
  
  // Not: Gerçek üretim uygulamaları için API anahtarlarını:
  // 1. Environment variables (.env dosyası)
  // 2. Secure storage (flutter_secure_storage paketi)
  // 3. Backend servis üzerinden
  // kullanmanız önerilir.
}