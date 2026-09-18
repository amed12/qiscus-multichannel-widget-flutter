# Push notification — panduan setup & diagnostic

Sample ini dipakai untuk memastikan device token benar-benar terdaftar ke
server Qiscus, dan untuk menemukan langkah mana yang gagal kalau push tidak
sampai.

Jalankan `Cek push notification (diagnostic)` dari halaman login.

---

## 1. Ganti empat hal ini dulu — wajib

App ID dan Channel ID sengaja dikosongkan jadi nilai isian, dan konfigurasi
Firebase bawaannya masih milik project contoh Qiscus. Selama belum diganti,
device Anda akan terdaftar ke lingkungan Qiscus — bukan lingkungan Anda —
sehingga hasil tesnya tidak bisa dipakai untuk menilai apa pun. Diagnostic
menolak jalan sampai keempatnya dibereskan.

| # | Ganti | Di mana | Jadi |
|---|-------|---------|------|
| 1 | App ID | isian `App ID` di layar diagnostic (bawaan `your_app_id`) | App ID Anda |
| 2 | Channel ID | isian `Channel ID (wajib)` di layar diagnostic (bawaan `your_channel_id`) | Channel ID Anda |
| 3 | Konfigurasi Firebase | `lib/firebase_options.dart` | Regenerate dengan `flutterfire configure` memakai project Firebase **Anda** |
| 4 | Bundle id / applicationId | `ios/Runner.xcodeproj`, `android/app/build.gradle` | Bundle yang **terdaftar di project Firebase Anda** |

Nomor 4 diperiksa otomatis di iOS: diagnostic membandingkan bundle id aplikasi
dengan `iosBundleId` di konfigurasi Firebase, dan gagal kalau berbeda. Bawaan
sample ini `com.example.multichannelFlutterSample`, jadi langkah ini memang
akan gagal sampai Anda regenerate konfigurasinya — itu disengaja.

Kalau Anda juga ingin memakai alur login penuh di sample ini, ganti `appId` dan
`channelId` di `lib/constant.dart` dengan nilai Anda.

Untuk nomor 3, alternatifnya letakkan file resmi dari Firebase Console:

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
mc.setChannelId(channelId);            // wajib — lihat catatan di bawah
mc.setUser(userId: ..., displayName: ...);
mc.setDeviceId(token, isDevelopment: kDebugMode);
await mc.initiateChat();               // <- baru di sini token dikirim ke server
```

Artinya, selama `initiateChat()` belum pernah sukses, device tidak akan pernah
terdaftar walau token yang didapat sudah benar. Diagnostic melaporkan kedua
langkah ini terpisah supaya jelas mana yang gagal.

### `channel_id` wajib diisi

Di request `initiate_chat`, `channel_id` bersifat **opsional** — kalau tidak
diisi, field-nya tidak ikut dikirim dan tidak ada error apa pun. Room tetap
terbentuk, tapi tidak menempel ke channel mana pun, dan gejalanya mudah
tertukar dengan "push tidak sampai".

Karena itu diagnostic ini menolak menjalankan `initiateChat()` selama Channel
ID masih kosong atau masih `your_channel_id`.

## 5. Membaca hasil diagnostic

Tombol **Salin hasil** menghasilkan teks siap tempel untuk dikirim balik ke tim
support. Isinya sudah menyamarkan token (hanya awalan/akhiran + panjangnya),
jadi aman ditempel di tiket.

| Langkah gagal | Artinya |
|---|---|
| Firebase ter-inisialisasi | `Firebase.initializeApp()` tidak ditunggu di `main()` |
| Konfigurasi menunjuk ke lingkungan Anda | App ID / Channel ID masih berisi nilai isian, atau masih memakai App ID / project contoh Qiscus — lihat bagian 1 |
| Channel ID terisi | Channel ID kosong atau masih `your_channel_id`; `initiateChat()` tidak dijalankan |
| Izin notifikasi disetujui | Izin ditolak di perangkat; aktifkan lewat Settings |
| APNs token tersedia | Simulator, capability belum aktif, atau APNs Auth Key belum ada di Firebase Console |
| Bundle id cocok dengan project Firebase | Bundle id aplikasi ≠ `iosBundleId` di konfigurasi Firebase. Selama tidak cocok, FCM menolak dengan `SenderId mismatch` walau token terbit |
| FCM token didapat | Konfigurasi Firebase tidak cocok dengan bundle id aplikasi |
| `initiateChat()` sukses | App ID / Channel ID salah, atau server tidak terjangkau |

Kalau semua langkah `[OK]` tapi push tetap tidak sampai, masalahnya bukan lagi
di aplikasi: token sudah terdaftar dengan benar, dan pengecekan berikutnya ada
di sisi kredensial FCM pada konfigurasi server Qiscus.
