# Mood Ring NFT – Dynamic NFTs Based on On-Chain Activity

**Mood Ring NFT** is a unique dynamic NFT system that reflects the behavioral patterns of its owner. Each NFT evolves over time based on the frequency and recency of interactions, transfers, and on-chain events. These evolving traits are reflected in mood states such as “Energetic,” “Calm,” or “Social,” which are determined by smart contract logic.

---

## 🔮 Key Features

* **Dynamic Mood State**: NFT moods change automatically based on blockchain activity like transfers and interactions.
* **On-chain Marketplace**: Built-in listing and buying mechanism with secure payment and ownership transfer.
* **NFT Minting**: Users can mint a Mood Ring NFT for a fee (default: 50 STX).
* **Interactive Engagement**: Owners can actively interact with their NFTs to boost activity levels and alter moods.

---

## 🧠 Mood Logic

### Mood States (Based on activity level):

| Mood ID | Mood Name     | Activity Threshold |
| ------- | ------------- | ------------------ |
| `u1`    | Energetic     | > 80               |
| `u3`    | Excited       | > 60               |
| `u5`    | Social        | > 40               |
| `u4`    | Contemplative | > 20               |
| `u2`    | Calm          | ≤ 20               |

* Mood is updated whenever the token is **transferred**, **interacted with**, or **purchased**.
* **Activity levels** increase with interaction and decrease with time.

---

## 📦 Core Contract Components

### NFT Standard (SIP-009)

* Implements `mint`, `transfer`, `get-owner`, and `get-token-uri`.

### Maps

* `token-moods`: Tracks current mood state and activity stats per token.
* `token-owners`: Maps token ID to owner.
* `token-listings`: Listings for NFT marketplace.
* `owner-tokens`: (Unused placeholder).

### Minting

* Mood is randomly initialized using `stacks-block-height % 5`.
* Base URI is configurable (`https://mood-ring-nft.com/api/` default).

---

## 🛠 Marketplace

* `list-for-sale(token-id, price)` – Owner lists token.
* `buy-token(token-id)` – Buyer sends STX and gets NFT.
* Automatically removes token from listings on successful purchase.

---

## 🤝 Owner Interaction

* `interact-with-token(token-id)` – Owner can manually boost activity.
* `update-mood-on-transfer(token-id)` – Private function called on transfers or purchases.

---

## 🧾 Read-Only Access

* `get-token-mood(token-id)`
* `get-mood-name(mood-id)`
* `get-listing(token-id)`
* `get-owner(token-id)`
* `get-token-uri(token-id)`
* `get-last-token-id()`

---

## ⚙️ Admin Controls

Only the contract owner can:

* `set-base-uri(new-uri)`
* `set-mint-price(new-price)`

---

## ⚠️ Error Codes

| Code   | Description                    |
| ------ | ------------------------------ |
| `u100` | Owner-only action              |
| `u101` | Not token owner                |
| `u102` | Token not found                |
| `u103` | Listing not found              |
| `u104` | Wrong price or invalid listing |
| `u105` | Invalid token ID               |
| `u106` | Invalid principal address      |
