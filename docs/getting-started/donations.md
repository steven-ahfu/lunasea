---
title: Donations
parent: Getting Started
nav_order: 4
---

# Donations

Open **About** at the bottom of the LunaSea drawer. In **Support development**, swipe or use the arrows to choose Bitcoin or Monero. Scan the QR code with your wallet or tap **Copy address**.

## Building from source

Set `BTC_ADDRESS` and `MONERO_ADDRESS` in the repository-root `.env`. From the `lunasea/` app directory, run `npm run generate:environment` before building. The generator reads only these two settings from the file. Leave an address empty to omit that currency.

For Android builds in GitHub Actions, configure the same names as repository secrets. The app embeds these public receive addresses at build time.
