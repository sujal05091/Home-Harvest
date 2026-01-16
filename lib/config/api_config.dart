/// API Configuration for HomeHarvest App
/// 
/// IMPORTANT: Add your actual API keys here before running the app
class ApiConfig {
  // Google Maps API Key
  // Get from: https://console.cloud.google.com/
  // Enable: Maps SDK for Android, Maps SDK for iOS, Directions API, Geocoding API
  static const String googleMapsApiKey = 'AIzaSyCo2gOBedGiddSXEmvB_EGo6DfENAWLg18';
  
  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'dycudtwkj';
  static const String cloudinaryUploadPreset = 'home_harvest_preset';
  
  // Razorpay Configuration (for payment gateway)
  static const String razorpayKeyId = 'YOUR_RAZORPAY_KEY_ID';
  static const String razorpayKeySecret = 'YOUR_RAZORPAY_KEY_SECRET';
  
  // Firebase Configuration (handled by google-services.json)
  // No need to add Firebase keys here
  
  // App Configuration
  static const String appName = 'HomeHarvest';
  static const String supportEmail = 'support@homeharvest.com';
  static const String supportPhone = '+91-6360577780';
  
  // Feature Flags
  static const bool enablePaymentGateway = false; // Set to true after adding Razorpay
  static const bool enableChatFeature = true;
  static const bool enableTiffinMode = true;
  static const bool enableRatingsReviews = true;
  
  // Geo Search Configuration
  static const double defaultSearchRadiusKm = 10.0;
  static const double maxSearchRadiusKm = 50.0;
  
  // Order Configuration
  static const int orderTimeoutMinutes = 30;
  static const double deliveryChargePerKm = 5.0;
  static const double minimumOrderAmount = 50.0;
  
  // Validation
  static bool isGoogleMapsConfigured() {
    return googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE' && 
           googleMapsApiKey.isNotEmpty;
  }
  
  static bool isCloudinaryConfigured() {
    return cloudinaryCloudName != 'your_cloud_name_here' && 
           cloudinaryCloudName.isNotEmpty;
  }
  
  static bool isRazorpayConfigured() {
    return razorpayKeyId != 'YOUR_RAZORPAY_KEY_ID' && 
           razorpayKeyId.isNotEmpty;
  }
}
