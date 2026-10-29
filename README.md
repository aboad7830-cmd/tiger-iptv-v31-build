# TIGER IPTV — iOS

SwiftUI IPTV client with libmpv player.

## Build IPA

```bash
cd ios
chmod +x build_ipa.sh
./build_ipa.sh --unsigned      # sideload IPA (Sideloadly / AltStore / TrollStore)
./build_ipa.sh                 # signed App Store IPA
```

Or run the **Build IPA** GitHub Actions workflow — the IPA appears as the `TigerIPTV-IPA` artifact.
