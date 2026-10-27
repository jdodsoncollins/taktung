# Approved privacy-page update for Tip Jar

Target: https://www.jeremycollins.net/taktung/privacy

The live October 21 page says “Taktung is not monetized.” Replace that sentence and its following sentence with:

> Taktung is free to use. You can choose to send an optional, repeatable tip through Apple In-App Purchase. Tips do not unlock features or start a subscription. Taktung does not use user data for advertising, profiling, resale, or cross-app tracking.

Add a short “Optional tips” section:

> Apple handles payment and App Store account information. Taktung receives StoreKit product information and transaction results on your device to verify and finish a tip. Taktung does not operate a purchase server, upload transactions, link tips to your Vercel account, or save a purchase history or tip total. A bounded set of transaction identifiers is kept only in memory while the app is running to prevent duplicate handling. Apple retains its own purchase records under App Store & Privacy.

Link “App Store & Privacy” to https://www.apple.com/legal/privacy/data/en/app-store/.

The remaining policy text stays unchanged. This describes the actual native implementation; it does not add tracking, a payment SDK or developer-side collection.

Approved by the user on October 21 and published through [website PR #30](https://github.com/jdodsoncollins/JeremyCollinsDotNet/pull/30). Production deployment `dpl_715nJfSE6GEVRLggAbdY3qMyDZt8` is READY; the public page was verified over HTTPS. The page introduction and Vercel-network paragraph were also aligned with the same optional Apple payment facts.
