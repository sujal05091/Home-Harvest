# 📸 Cloudinary Setup Guide - FREE Image Storage

## Why Cloudinary Instead of Firebase Storage?

✅ **FREE Tier** - 25GB storage, 25GB bandwidth/month (no credit card)  
✅ **Image Transformations** - Auto resize, crop, optimize  
✅ **CDN Delivery** - Fast global image loading  
✅ **Easy Integration** - Simple Flutter package  
✅ **No Payment Required** - Firebase Storage needs Blaze plan

---

## 🚀 Step 1: Create Cloudinary Account (2 minutes)

1. Go to **https://cloudinary.com/users/register_free**
2. Sign up with email (no credit card needed)
3. Verify your email
4. You'll see the Dashboard

---

## 🔑 Step 2: Get Your Credentials (1 minute)

After login, you'll see the Dashboard with:

```
Cloud name: demo_app_123
API Key: 123456789012345
API Secret: AbCdEfGhIjKlMnOpQrStUvWxYz
```

**Copy your `Cloud name`** - you'll need it!

---

## ⚙️ Step 3: Create Upload Preset (2 minutes)

### Why? 
Upload presets allow secure uploads without exposing API secrets in your app.

### Steps:
1. In Cloudinary Dashboard, go to **Settings** (gear icon)
2. Click **Upload** tab
3. Scroll to **Upload presets**
4. Click **Add upload preset**
5. Configure:
   - **Preset name**: `home_harvest_preset`
   - **Signing Mode**: **Unsigned** ✅
   - **Folder**: Leave empty (we set it in code)
   - **Use filename**: Yes
   - **Unique filename**: Yes
6. Click **Save**

---

## 💻 Step 4: Update Your Flutter Code (1 minute)

Open `lib/services/storage_service.dart` and replace:

```dart
static const String CLOUDINARY_CLOUD_NAME = 'your_cloud_name_here';
static const String CLOUDINARY_UPLOAD_PRESET = 'home_harvest_preset';
```

With your actual values:

```dart
static const String CLOUDINARY_CLOUD_NAME = 'demo_app_123';  // Your cloud name
static const String CLOUDINARY_UPLOAD_PRESET = 'home_harvest_preset';
```

---

## 📦 Step 5: Install Package (1 minute)

Run in terminal:

```bash
cd "c:\\Users\\sujal\\OneDrive\\Desktop\\Home Harvest Project\\home_harvest_app"
flutter pub get
```

This installs the `cloudinary_public` package.

---

## ✅ Step 6: Test Upload (Optional)

Run your app and try uploading a dish image. Images will be stored at:

```
https://res.cloudinary.com/<your-cloud-name>/image/upload/home_harvest/dishes/...
```

---

## 📁 Folder Structure

Your images will be organized as:

```
home_harvest/
├── dishes/          # Dish photos uploaded by cooks
├── verifications/   # Cook verification documents
│   └── {userId}/    # Organized by user
└── profiles/        # User profile pictures
```

---

## 🎨 Image Transformations (Bonus)

Cloudinary automatically optimizes images. You can also transform URLs:

### Resize image to 300x300:
```
https://res.cloudinary.com/demo/image/upload/w_300,h_300,c_fill/home_harvest/dishes/image.jpg
```

### Convert to WebP:
```
https://res.cloudinary.com/demo/image/upload/f_webp/home_harvest/dishes/image.jpg
```

### Add to Flutter code:
```dart
// In dish_card.dart or wherever you display images
Image.network(
  '${dish.imageUrl.replaceAll('/upload/', '/upload/w_300,h_300,c_fill/')}',
  fit: BoxFit.cover,
)
```

---

## 🔒 Security Best Practices

### Current Setup (Unsigned Upload)
✅ Good for MVP/testing  
⚠️ Anyone with preset name can upload  

### Production Setup (Signed Upload)
For production, use **signed uploads** with backend:

1. Change preset to **Signed mode**
2. Create a backend endpoint (Node.js/Firebase Functions)
3. Generate signature on backend using API secret
4. Flutter app calls backend → gets signature → uploads

**For now, unsigned is fine** for development!

---

## 💰 Free Tier Limits

| Feature | Free Tier |
|---------|-----------|
| Storage | 25 GB |
| Bandwidth | 25 GB/month |
| Transformations | 25 Credits/month |
| Images | Unlimited |

**Tip**: 25GB = ~25,000 images at 1MB each - plenty for testing!

---

## 🆚 Cloudinary vs Firebase Storage

| Feature | Cloudinary FREE | Firebase Storage |
|---------|-----------------|------------------|
| Cost | $0 | Requires Blaze plan |
| Storage | 25 GB | Pay per GB |
| Bandwidth | 25 GB/month | Pay per GB |
| Transformations | ✅ Built-in | ❌ Need Cloud Functions |
| CDN | ✅ Global | ✅ Global |
| Credit Card | ❌ Not needed | ✅ Required |

---

## 🐛 Troubleshooting

### Error: "Missing required parameter - file"
- Check image file exists: `print(imageFile.path)`
- Verify file is not empty

### Error: "Invalid cloud name"
- Double-check `CLOUDINARY_CLOUD_NAME` matches Dashboard
- Remove spaces/quotes

### Error: "Upload preset not found"
- Verify preset name is exactly `home_harvest_preset`
- Check preset is **Unsigned**

### Images not loading
- Check returned `secureUrl` in console
- Verify URL starts with `https://res.cloudinary.com/`
- Test URL directly in browser

---

## 📊 Monitor Usage

View usage in Cloudinary Dashboard:
1. Go to **Settings** → **Usage**
2. See storage, bandwidth, transformations
3. Get alerts before hitting limits

---

## 🎯 What Changed in Your Code?

### ✅ Updated Files:
1. **pubspec.yaml** - Replaced `firebase_storage` with `cloudinary_public`
2. **storage_service.dart** - Complete rewrite for Cloudinary API

### ✅ No Changes Needed:
- All screen files (add_dish.dart, verification_status.dart, etc.)
- API remains the same: `uploadDishImage()`, `uploadVerificationImages()`
- Your existing code works as-is!

---

## 🚀 Next Steps

1. ✅ Sign up for Cloudinary
2. ✅ Copy your `cloud_name`
3. ✅ Create `home_harvest_preset` (unsigned)
4. ✅ Update `storage_service.dart` with credentials
5. ✅ Run `flutter pub get`
6. ✅ Test image upload in your app

---

## 📞 Support

**Cloudinary Docs**: https://cloudinary.com/documentation/flutter_integration  
**Package Docs**: https://pub.dev/packages/cloudinary_public  
**Dashboard**: https://cloudinary.com/console

---

**You're all set! 🎉 No payment needed, no credit card, just free image storage!**
