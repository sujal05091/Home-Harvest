# 🗺️ **GOOGLE MAPS FIX - TROUBLESHOOTING GUIDE**

## **✅ FIXES APPLIED**

### **1. Updated `android/app/build.gradle.kts`:**
```gradle
✅ Set minSdk = 21 (Required for Google Maps)
✅ Added multiDexEnabled = true
✅ Added Google Play Services dependencies:
   - play-services-maps:18.2.0
   - play-services-location:21.0.1
```

### **2. Updated `AndroidManifest.xml`:**
```xml
✅ Added INTERNET permission
✅ Added ACCESS_NETWORK_STATE permission
✅ Added usesCleartextTraffic="true"
✅ Google Maps API Key already configured
```

---

## **🔑 IMPORTANT: ENABLE GOOGLE MAPS APIs**

Your API Key: `AIzaSyCo2gOBedGiddSXEmvB_EGo6DfENAWLg18`

### **Must Enable These APIs in Google Cloud Console:**

1. Go to: https://console.cloud.google.com/

2. Select your project

3. **Enable these APIs:**
   - ✅ **Maps SDK for Android**
   - ✅ **Maps SDK for iOS** (if testing on iOS)
   - ✅ **Directions API** (for route polylines)
   - ✅ **Geocoding API** (for address search)
   - ✅ **Places API** (for location search)

4. **Steps to enable:**
   ```
   Navigation Menu → APIs & Services → Library
   → Search "Maps SDK for Android" → Click → ENABLE
   → Search "Directions API" → Click → ENABLE
   → Search "Geocoding API" → Click → ENABLE
   → Search "Places API" → Click → ENABLE
   ```

---

## **🚀 BUILD & RUN STEPS**

### **1. Clean Build:**
```bash
cd "c:\Users\sujal\Desktop\Home Harvest Project\home_harvest_app"
flutter clean
flutter pub get
```

### **2. Run App:**
```bash
flutter run
```

### **3. If map still doesn't show:**

**Check Console for errors:**
```
Look for messages like:
- "Maps SDK for Android API has not been used"
- "This API key is not authorized to use this service"
- "AUTHORIZATION_FAILURE"
```

**Solution:** Enable the required APIs in Google Cloud Console (see above)

---

## **📱 TESTING MAP SCREENS**

### **1. Order Tracking Map:**
```
Customer → Place Order → Cook Accepts → Track Order
Should show: Pickup marker, Drop marker, Rider marker (when assigned)
```

### **2. Location Picker Map:**
```
Customer → Add Address → "Select on Map"
Should show: Full-screen interactive map with draggable pin
```

### **3. Rider Navigation:**
```
Rider → Accept Order → Navigate
Should show: Google Maps with route from pickup to drop
```

---

## **🔍 COMMON ISSUES & FIXES**

### **Issue 1: Blank Gray Screen**
**Cause:** APIs not enabled  
**Fix:** Enable Maps SDK for Android in Google Cloud Console

### **Issue 2: Map shows but no markers**
**Cause:** Location permissions not granted  
**Fix:** 
```
Settings → Apps → home_harvest_app → Permissions → Location → Allow all the time
```

### **Issue 3: "Authorization Failure"**
**Cause:** API Key restrictions  
**Fix:** Go to Google Cloud Console → Credentials → Click your API key → Under "Application restrictions" select "None" (for testing)

### **Issue 4: Map loads slowly**
**Cause:** Network connection or API quota  
**Fix:** Check internet connection and API usage in Google Cloud Console

---

## **📋 VERIFICATION CHECKLIST**

Before running the app:

- [ ] Google Cloud Console project created
- [ ] Maps SDK for Android ENABLED
- [ ] Directions API ENABLED
- [ ] Geocoding API ENABLED
- [ ] API Key has no restrictions (for testing)
- [ ] flutter clean executed
- [ ] flutter pub get executed
- [ ] Location permissions granted on device
- [ ] Internet connection working

---

## **🔄 IF STILL NOT WORKING**

### **Check API Key:**
```bash
# Verify API key in AndroidManifest.xml
cat android/app/src/main/AndroidManifest.xml | grep "API_KEY"
```

Should show:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyCo2gOBedGiddSXEmvB_EGo6DfENAWLg18"/>
```

### **Check API Status:**
1. Go to: https://console.cloud.google.com/apis/dashboard
2. Select your project
3. Check "ENABLED APIS & SERVICES"
4. Should see: Maps SDK for Android, Directions API, Geocoding API

### **Enable Billing (Required for Google Maps):**
Google Maps requires a billing account (but has free tier):
- $200 free credit per month
- Maps loads: 28,000 free per month
- Most apps stay within free tier

Steps:
1. Google Cloud Console → Billing
2. Link a billing account (requires credit card)
3. Don't worry - you won't be charged unless you exceed free tier

---

## **💡 QUICK TEST**

After making changes, test with this simple flow:

1. **Start app** → Sign up as Customer
2. **Click "Add Address"** button
3. **Click "Select on Map"** button
4. **Map should load** with your current location
5. **Tap anywhere** → Pin should drop
6. **Drag pin** → Address should update

If this works, all map screens will work!

---

## **📞 STILL NEED HELP?**

Check logcat output:
```bash
flutter run -v
```

Look for errors containing:
- "Maps"
- "Google"
- "API_KEY"
- "Authorization"

Common error message:
```
"The Google Maps Platform server rejected your request. 
This API project is not authorized to use this API."
```

**Solution:** Enable Maps SDK for Android API in Cloud Console!

---

## **✨ SUMMARY**

**What I Fixed:**
1. ✅ Added minSdk = 21
2. ✅ Added Google Play Services dependencies
3. ✅ Added internet permissions
4. ✅ Added multiDex support

**What YOU Need to Do:**
1. 🔑 **Enable Maps SDK for Android** in Google Cloud Console
2. 🔑 **Enable Directions API**
3. 🔑 **Enable Geocoding API**
4. 💳 **Link billing account** (free tier available)
5. 🔄 Run `flutter clean` and `flutter pub get`
6. 🚀 Run the app

**After enabling APIs, map should work perfectly!** 🗺️
