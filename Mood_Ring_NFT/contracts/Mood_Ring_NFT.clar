;; Mood Ring NFT - Dynamic NFTs Based on On-Chain Activity
;; NFTs that evolve based on owner's transaction patterns

;; Traits
(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 200)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-wrong-price (err u104))
(define-constant err-invalid-token-id (err u105))
(define-constant err-invalid-principal (err u106))

;; Mood constants
(define-constant mood-energetic u1)
(define-constant mood-calm u2)
(define-constant mood-excited u3)
(define-constant mood-contemplative u4)
(define-constant mood-social u5)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var mint-price uint u50000000) ;; 50 STX
(define-data-var base-uri (string-ascii 100) "https://mood-ring-nft.com/api/")

;; Data Maps
(define-map token-moods
  uint
  {
    base-mood: uint,
    activity-level: uint,
    last-interaction: uint,
    interaction-count: uint
  }
)

(define-map token-owners uint principal)
(define-map owner-tokens principal (list 100 uint))
(define-map token-listings
  uint
  {
    price: uint,
    seller: principal
  }
)

;; SIP-009 NFT Functions
(define-non-fungible-token mood-ring uint)

;; Input validation helpers
(define-private (is-valid-token-id (token-id uint))
  (and (> token-id u0) (<= token-id (var-get last-token-id)))
)

(define-private (is-valid-principal (principal-to-check principal))
  (not (is-eq principal-to-check 'SP000000000000000000002Q6VF78))
)

;; Helper function to get single digit as string
(define-private (get-digit-string (digit uint))
  (if (is-eq digit u0) "0"
    (if (is-eq digit u1) "1"
      (if (is-eq digit u2) "2"
        (if (is-eq digit u3) "3"
          (if (is-eq digit u4) "4"
            (if (is-eq digit u5) "5"
              (if (is-eq digit u6) "6"
                (if (is-eq digit u7) "7"
                  (if (is-eq digit u8) "8"
                    "9"
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Simple uint to string conversion (handles up to 999)
(define-private (uint-to-string (n uint))
  (if (< n u10)
    (get-digit-string n)
    (if (< n u100)
      (let ((tens (/ n u10)) (ones (mod n u10)))
        (concat (get-digit-string tens) (get-digit-string ones))
      )
      (if (< n u1000)
        (let 
          (
            (hundreds (/ n u100))
            (tens (mod (/ n u10) u10))
            (ones (mod n u10))
          )
          (concat 
            (concat (get-digit-string hundreds) (get-digit-string tens))
            (get-digit-string ones)
          )
        )
        "999+"
      )
    )
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; Input validation
    (asserts! (is-valid-token-id token-id) err-invalid-token-id)
    (asserts! (is-valid-principal sender) err-invalid-principal)
    (asserts! (is-valid-principal recipient) err-invalid-principal)
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    
    ;; Verify ownership
    (asserts! (is-eq (some sender) (nft-get-owner? mood-ring token-id)) err-not-token-owner)
    
    ;; Execute transfer
    (try! (nft-transfer? mood-ring token-id sender recipient))
    (update-mood-on-transfer token-id)
    (ok true)
  )
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (if (is-valid-token-id token-id)
    (ok (some (concat (var-get base-uri) (uint-to-string token-id))))
    (ok none)
  )
)

(define-read-only (get-owner (token-id uint))
  (if (is-valid-token-id token-id)
    (ok (nft-get-owner? mood-ring token-id))
    (err err-invalid-token-id)
  )
)

;; Mint Function
(define-public (mint)
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (initial-mood (mod stacks-block-height u5)) ;; Random initial mood based on block
    )
    ;; Payment
    (try! (stx-transfer? (var-get mint-price) tx-sender contract-owner))
    
    ;; Mint NFT
    (try! (nft-mint? mood-ring token-id tx-sender))
    
    ;; Set initial mood data
    (map-set token-moods token-id {
      base-mood: (if (is-eq initial-mood u0) u1 initial-mood),
      activity-level: u50,
      last-interaction: stacks-block-height,
      interaction-count: u1
    })
    
    ;; Update token tracking
    (map-set token-owners token-id tx-sender)
    (var-set last-token-id token-id)
    
    (ok token-id)
  )
)

;; Mood Update Functions
(define-private (update-mood-on-transfer (token-id uint))
  (match (map-get? token-moods token-id)
    current-mood
    (let
      (
        (time-since-last (- stacks-block-height (get last-interaction current-mood)))
        (new-activity (calculate-activity-level (get activity-level current-mood) time-since-last))
      )
      (map-set token-moods token-id
        (merge current-mood {
          activity-level: new-activity,
          last-interaction: stacks-block-height,
          interaction-count: (+ (get interaction-count current-mood) u1),
          base-mood: (calculate-new-mood (get base-mood current-mood) new-activity)
        })
      )
      true
    )
    false
  )
)

(define-private (calculate-activity-level (current-level uint) (blocks-passed uint))
  (if (< blocks-passed u144) ;; Less than ~1 day
    (min u100 (+ current-level u10))
    (if (< blocks-passed u1008) ;; Less than ~1 week
      current-level
      (max u0 (- current-level u20))
    )
  )
)

(define-private (calculate-new-mood (current-mood uint) (activity-level uint))
  (if (> activity-level u80)
    mood-energetic
    (if (> activity-level u60)
      mood-excited
      (if (> activity-level u40)
        mood-social
        (if (> activity-level u20)
          mood-contemplative
          mood-calm
        )
      )
    )
  )
)

;; Marketplace Functions
(define-public (list-for-sale (token-id uint) (price uint))
  (let
    (
      (token-owner (nft-get-owner? mood-ring token-id))
    )
    ;; Input validation
    (asserts! (is-valid-token-id token-id) err-invalid-token-id)
    (asserts! (> price u0) err-wrong-price)
    
    ;; Ownership validation
    (asserts! (is-some token-owner) err-token-not-found)
    (asserts! (is-eq tx-sender (unwrap-panic token-owner)) err-not-token-owner)
    
    (map-set token-listings token-id {
      price: price,
      seller: tx-sender
    })
    
    (ok true)
  )
)

(define-public (buy-token (token-id uint))
  (let
    (
      (listing (map-get? token-listings token-id))
    )
    ;; Input validation
    (asserts! (is-valid-token-id token-id) err-invalid-token-id)
    (asserts! (is-some listing) err-listing-not-found)
    
    (let
      (
        (listing-data (unwrap-panic listing))
        (price (get price listing-data))
        (seller (get seller listing-data))
      )
      ;; Additional validation
      (asserts! (is-valid-principal seller) err-invalid-principal)
      (asserts! (not (is-eq tx-sender seller)) err-not-token-owner)
      
      ;; Payment
      (try! (stx-transfer? price tx-sender seller))
      
      ;; Transfer NFT
      (try! (nft-transfer? mood-ring token-id seller tx-sender))
      
      ;; Update mood on purchase
      (update-mood-on-transfer token-id)
      
      ;; Remove listing
      (map-delete token-listings token-id)
      
      (ok true)
    )
  )
)

;; Interactive Functions to Influence Mood
(define-public (interact-with-token (token-id uint))
  (let
    (
      (token-owner (nft-get-owner? mood-ring token-id))
    )
    ;; Input validation
    (asserts! (is-valid-token-id token-id) err-invalid-token-id)
    (asserts! (is-some token-owner) err-token-not-found)
    (asserts! (is-eq tx-sender (unwrap-panic token-owner)) err-not-token-owner)
    
    (update-mood-on-transfer token-id)
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-token-mood (token-id uint))
  (if (is-valid-token-id token-id)
    (map-get? token-moods token-id)
    none
  )
)

(define-read-only (get-mood-name (mood-id uint))
  (if (is-eq mood-id mood-energetic) "Energetic"
    (if (is-eq mood-id mood-calm) "Calm"
      (if (is-eq mood-id mood-excited) "Excited"
        (if (is-eq mood-id mood-contemplative) "Contemplative"
          (if (is-eq mood-id mood-social) "Social"
            "Unknown"
          )
        )
      )
    )
  )
)

(define-read-only (get-listing (token-id uint))
  (if (is-valid-token-id token-id)
    (map-get? token-listings token-id)
    none
  )
)

;; Helper functions
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

;; Admin functions
(define-public (set-base-uri (new-uri (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set base-uri new-uri)
    (ok true)
  )
)

(define-public (set-mint-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set mint-price new-price)
    (ok true)
  )
)
