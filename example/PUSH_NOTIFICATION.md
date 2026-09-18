# Push notification — panduan setup & diagnostic

Sample ini dipakai untuk memastikan device token benar-benar terdaftar ke
server Qiscus, dan untuk menemukan langkah mana yang gagal kalau push tidak
sampai.

Jalankan `Cek push notification (diagnostic)` dari halaman login.

---

## 1. Ganti tiga hal ini dulu — wajib

Sample ini bawaannya menunjuk ke App ID dan project Firebase **milik contoh
Qiscus**. Kalau dijalankan apa adanya, device Anda terdaftar ke lingkungan
Qiscus, bukan lingkungan Anda — hasil tesnya tidak bisa dipakai untuk menilai
apa pun. Diagnostic akan menolak jalan sampai ini dibereskan.

| # | Ganti | Di mana | Jadi |
|---|-------|---------|------|
| 1 | App ID | `lib/constant.dart` → `appId` | App ID Anda |
| 2 | Konfigurasi Firebase | `lib/firebase_options.dart` | Regenerate dengan `flutterfire configure` memakai project Firebase **Anda** |
| 3 | Bundle id / applicationId | `ios/Runner.xcodeproj`, `android/app/build.gradle` | Bundle yang **terdaftar di project Firebase Anda** |

Untuk nomor 2, alternatifnya letakkan file resmi dari Firebase Console:

- Android → `android/app/google-services.json`
- iOS → `ios/Runner/GoogleService-Info.plist`

Kalau bundle id aplikasi tidak terdaftar di project Firebase yang dipakai, FCM
akan menolak pengiriman walau token berhasil terbit.

## 2. Syarat khusus iOS

- **Perangkat fisik.** Simulator tidak menerbitkan APNs token, jadi push tidak
  bisa diuji di sana.
- **Capability `Push Notifications`** aktif di Xcode (tab Signing &
  Capabilities), plus `Background Modes` → `Remote notifications`.
- **APNs Auth Key (.p8) sudah diunggah ke Firebase Console** Anda, di Project
  Settings → Cloud Messaging. Ini yang dipakai Firebase untuk meneruskan pesan
  ke APNs.
- Sertifikat `.p12` **tidak** perlu diunggah ke Qiscus untuk integrasi Flutter.
  Jalur Flutter memakai FCM; kredensial Apple-nya cukup ada di Firebase Console
  Anda.

## 3. Urutan pemanggilan yang benar

Ini bagian yang paling sering salah, dan gagalnya senyap di iOS.

```dart
// 1. Minta izin DULU — sebelum disetujui, iOS belum menerbitkan APNs token.
final settings = await FirebaseMessaging.instance.requestPermission(
  alert: true, badge: true, sound: true,
);

// 2. Tunggu APNs token terbit (iOS/macOS).
//    Tanpa ini, getToken() bisa mengembalikan null walau izin sudah disetujui.
if (Platform.isIOS || Platform.isMacOS) {
  await FirebaseMessaging.instance.getAPNSToken();
}

// 3. Baru ambil FCM token.
final token = await FirebaseMessaging.instance.getToken();

// 4. Serahkan ke widget. isDevelopment mengikuti tipe build.
if (token != null) {
  mc.setDeviceId(token, isDevelopment: kDebugMode);
}
```

Memanggil `getToken()` lebih dulu membuat token `null` di iOS **tanpa error yang
terlihat** — kalau errornya hanya di-`print` di dalam `catchError`, `setDeviceId()`
tidak pernah menerima token apa pun dan device tidak akan pernah terdaftar.

## 4. `setDeviceId()` saja tidak mendaftarkan apa pun

`setDeviceId()` hanya **menyimpan** token di memori widget. Yang benar-benar
mengirimkannya ke endpoint `set_user_device_token` adalah **`initiateChat()`**.

```dart
mc.setDeviceId(token, isDevelopment: kDebugMode);
await mc.initiateChat();   // <- baru di sini token dikirim ke server
```

Artinya, selama `initiateChat()` belum pernah sukses, device tidak akan pernah
terdaftar walau token yang didapat sudah benar. Diagnostic melaporkan kedua
langkah ini terpisah supaya jelas mana yang gagal.

## 5. Membaca hasil diagnostic

Tombol **Salin hasil** menghasilkan teks siap tempel untuk dikirim balik ke tim
support. Isinya sudah menyamarkan token (hanya awalan/akhiran + panjangnya),
jadi aman ditempel di tiket.

| Langkah gagal | Artinya |
|---|---|
| Firebase ter-inisialisasi | `Firebase.initializeApp()` tidak ditunggu di `main()` |
| Konfigurasi menunjuk ke lingkungan Anda | Masih memakai App ID / project contoh Qiscus — lihat bagian 1 |
| Izin notifikasi disetujui | Izin ditolak di perangkat; aktifkan lewat Settings |
| APNs token tersedia | Simulator, capability belum aktif, atau APNs Auth Key belum ada di Firebase Console |
| FCM token didapat | Konfigurasi Firebase tidak cocok dengan bundle id aplikasi |
| `initiateChat()` sukses | App ID / Channel ID salah, atau server tidak terjangkau |

Kalau semua langkah `[OK]` tapi push tetap tidak sampai, masalahnya bukan lagi
di aplikasi: token sudah terdaftar dengan benar, dan pengecekan berikutnya ada
di sisi kredensial FCM pada konfigurasi server Qiscus.
