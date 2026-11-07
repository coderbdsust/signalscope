## 1) pubspec.yaml
```yaml
flutter:
  assets:
    - assets/oui.csv
```

## 2) MainActivity.kt – add `hostname` to each device map
Where you build each device entry in `scanLanDevices` (the map that already has
`ip`, `mac`, `role`), add a reverse-DNS name. Run it off the main thread
(you're already scanning on a background executor):

```kotlin
private fun hostnameFor(ip: String): String? = try {
    val name = java.net.InetAddress.getByName(ip).canonicalHostName
    if (name.isNullOrBlank() || name == ip) null else name
} catch (_: Exception) { null }

// ...when creating the device map:
mapOf(
    "ip" to ip,
    "mac" to mac,
    "role" to role,
    "hostname" to hostnameFor(ip)
)
```
Dart treats a missing/null `hostname` as "no name", so this step is optional.
