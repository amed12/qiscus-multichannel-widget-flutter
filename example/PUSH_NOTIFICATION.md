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

- **Perangkat fisik, dan jalankan lewat Xcode** (bukan cuma `flutter run`,
  supaya console Xcode bisa dilihat langsung untuk baris log `[push][background]`
  di bagian 6). Simulator tidak menerbitkan APNs token, jadi push tidak bisa
  diuji di sana sama sekali.
- **Capability `Push Notifications`** dan **`Background Modes` → `Remote
  notifications`** — sudah otomatis ada di `ios/Runner/Runner.entitlements`
  dan `Info.plist` sample ini. Kalau ini dipindahkan ke project Anda sendiri
  (bukan menjalankan sample apa adanya), pastikan dua capability ini juga
  aktif di project Anda — cek di Xcode: Signing & Capabilities.
- **APNs Auth Key (.p8) sudah diunggah ke Firebase Console** Anda, di Project
  Settings → Cloud Messaging. Ini yang dipakai Firebase untuk meneruskan pesan
  ke APNs — **wajib**, disebut eksplisit di dokumentasi resmi Firebase untuk
  **Flutter** ("Mengupload kunci autentikasi APN", bagian iOS+):
  [Get started with FCM in Flutter apps](https://firebase.google.com/docs/cloud-messaging/flutter/get-started?hl=id).
  **Satu key yang sama otomatis berlaku untuk environment Development maupun
  Production** ([sumber: Apple Developer](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens/))
  — tidak perlu diunggah dua kali kecuali Anda sengaja memakai team-scoped key
  yang dibatasi ke satu environment saja.
- **Development vs Production APNs itu ditentukan Xcode saat build, bukan oleh
  kode Dart.** Menjalankan app langsung dari Xcode ke device (apa pun
  konfigurasi Debug/Release) selalu memakai environment **Development**
  (sandbox); baru saat diarsipkan untuk TestFlight/App Store dengan
  distribution profile, environment-nya jadi **Production**. `isDevelopment:
  kDebugMode` di kode ini cuma pendekatan yang cocok untuk `flutter run` biasa
  — kalau Anda run lewat Xcode dengan skema Release, `kDebugMode` bisa `false`
  padahal environment APNs-nya tetap Development.
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

## 6. Kalau registrasi sudah `[OK]` tapi notifikasi tetap tidak muncul

Ini bagian baru — untuk kasus token sudah terdaftar & CS sudah membalas, tapi
device tidak menampilkan apa pun. Layar diagnostic ini sekarang juga mencatat
**pesan yang benar-benar diterima app**, bukan cuma "server bilang sukses
kirim".

### Protokol pengujian — ikuti urutan ini persis

1. Jalankan app dari **Xcode** ke **device fisik**, biarkan jendela console
   Xcode tetap terbuka supaya baris log terlihat.
2. Buka `Cek push notification (diagnostic)`, isi App ID/Channel ID/User ID
   milik Anda, tekan **Jalankan diagnostic**. Pastikan semua langkah `[OK]`.
3. **Sambil app masih di foreground**, minta CS membalas di room yang sama.
   Tunggu baris baru muncul di bagian "Log pesan yang benar-benar diterima
   app" di layar ini — **ini langkah paling penting**, karena bentuk payload
   sama saja baik app foreground maupun background, dan cuma bisa dibaca
   dengan mudah saat foreground.
4. Tekan tombol Home / pindah ke app lain (app jadi background, **jangan** di-
   swipe close). Minta CS membalas lagi di room yang sama.
5. Amati apakah notifikasi muncul di layar device. Kalau tidak, buka kembali
   console Xcode dan cari baris `[push][background] messageId=...`.
6. Tekan **Salin hasil**, tempel ke satu pesan, **lalu tambahkan manual** baris
   `[push][background]` dari console Xcode langkah 5 (baris ini tidak
   otomatis ikut ter-copy karena berjalan di isolate terpisah).
7. Sertakan juga: jam persis langkah 3 dan langkah 4 dilakukan (WIB), supaya
   bisa dicocokkan dengan log pengiriman di sisi server Qiscus.

Kirim hasil gabungan langkah 6 dan 7 itu ke tim support untuk dianalisis.

### Contoh log yang seharusnya muncul di langkah 3 (foreground)

Kondisi sehat — payload berisi alert, ini yang diharapkan:

```
[14:03:07] (foreground) messageId=0:1758... · payload=notification (title: "Pesan baru", body: "...") · data={roomId: ..., type: ...}
```

Kondisi bermasalah — payload data-only, ini kandidat penyebab langsung:

```
[14:03:07] (foreground) messageId=0:1758... · payload=DATA-ONLY (tidak ada blok notification!) · data={roomId: ..., type: ...}
```

Contoh baris `[push][background]` di console Xcode (langkah 5), pola sama:

```
flutter: [push][background] messageId=0:1758... notification=NULL (data-only) data={roomId: ..., type: ...}
flutter: [push][background] messageId=0:1758... notification=ADA (title: Pesan baru) data={roomId: ..., type: ...}
```

### Tabel diagnosis — baca hasilnya, jangan cuma kirim mentah

| Log foreground (langkah 3) | Banner muncul saat background (langkah 5)? | Baris `[push][background]` di console? | Kesimpulan | Siapa yang tindak lanjut |
|---|---|---|---|---|
| `notification` (ada title/body) | Ya | Ya | **Sehat.** Registrasi, capability, dan payload semua benar. | Selesai |
| `notification` (ada title/body) | **Tidak** | Ya | Payload benar & sampai ke app, tapi OS tidak menampilkan banner. Cek: mode Fokus/Do Not Disturb device, izin notifikasi di Settings device (bukan cuma dialog izin di app), atau app masih dianggap "foreground" oleh iOS. | Client (cek device), lalu tim support kalau tetap gagal |
| `notification` (ada title/body) | **Tidak** | **Tidak ada baris sama sekali** | Pesan tidak sampai ke device sama sekali walau payload-nya benar. Kandidat: APNs Auth Key revoked/salah Team ID, atau Push Notifications capability tidak ikut ter-include di build yang dipasang ke device (misal build lama sebelum entitlements ditambahkan). | Client verifikasi APNs Auth Key di Firebase Console + rebuild & install ulang |
| **`DATA-ONLY`** | **Tidak** | Ya (data-only juga) | **Kandidat kuat.** Server (Qiscus) mengirim pesan tanpa blok `notification`/`aps.alert`, jadi iOS memang tidak akan pernah menampilkan banner otomatis saat background/killed — ini bukan bug di app. | Tim Qiscus (cek payload push CS reply di backend) |
| `DATA-ONLY` | **Ya** (tetap muncul) | Ya | Kemungkinan ada logic lain yang menampilkan notifikasi lokal dari data (mis. plugin lain). Jarang terjadi, catat detailnya kalau ini yang muncul. | Tim support (perlu investigasi lanjut) |
| **Tidak ada baris apa pun** setelah CS membalas (foreground) | — | — | Pesan tidak sampai ke app sama sekali walau app foreground — kemungkinan token yang terdaftar bukan token device ini, atau `initiateChat()` sebelumnya gagal diam-diam. Ulangi dari langkah 2. | Client (ulangi diagnostic dari awal) |
