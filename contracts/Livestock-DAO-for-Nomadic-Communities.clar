(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-auction-not-found (err u105))
(define-constant err-auction-ended (err u106))
(define-constant err-bid-too-low (err u107))
(define-constant err-not-seller (err u108))

;; CowCoin Token
(define-fungible-token cowcoin)

;; Data Maps
(define-map livestock-registry 
    { id: uint }
    { owner: principal, species: (string-ascii 20), age: uint, health-status: (string-ascii 10) })

(define-map insurance-pools
    { pool-id: uint }
    { total-stake: uint, members: uint, active: bool })

(define-map vet-claims
    { claim-id: uint }
    { livestock-id: uint, description: (string-ascii 50), amount: uint, status: (string-ascii 10) })

(define-map livestock-reputation
    { livestock-id: uint }
    { score: uint, health-events: uint, breeding-success: uint, productivity-rating: uint })

(define-map reputation-events
    { event-id: uint }
    { livestock-id: uint, event-type: (string-ascii 20), impact: int, reporter: principal })

(define-map livestock-auctions
    { auction-id: uint }
    { livestock-id: uint, seller: principal, start-price: uint, current-bid: uint, bidder: (optional principal), end-block: uint })

(define-data-var next-livestock-id uint u1)
(define-data-var next-pool-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var next-event-id uint u1)
(define-data-var next-auction-id uint u1)

;; Core Functions
(define-public (register-livestock (species (string-ascii 20)) (age uint))
    (let ((livestock-id (var-get next-livestock-id)))
        (map-insert livestock-registry
            { id: livestock-id }
            { owner: tx-sender, species: species, age: age, health-status: "healthy" }
        )
        (var-set next-livestock-id (+ livestock-id u1))
        (map-insert livestock-reputation
            { livestock-id: livestock-id }
            { score: u100, health-events: u0, breeding-success: u0, productivity-rating: u50 }
        )
        (try! (mint-cowcoin livestock-id))
        (ok livestock-id)))
(define-public (transfer-livestock (livestock-id uint) (new-owner principal))
    (let ((livestock (unwrap! (map-get? livestock-registry { id: livestock-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get owner livestock)) err-owner-only)
        (map-set livestock-registry
            { id: livestock-id }
            (merge livestock { owner: new-owner })
        )

        (try! (transfer-cowcoin livestock-id new-owner))
        (ok true)))
(define-public (create-insurance-pool)
    (let ((pool-id (var-get next-pool-id)))
        (map-insert insurance-pools
            { pool-id: pool-id }
            { total-stake: u0, members: u0, active: true }
        )
        (var-set next-pool-id (+ pool-id u1))
        (ok pool-id)))

(define-public (stake-in-pool (pool-id uint) (amount uint))
    (let ((pool (unwrap! (map-get? insurance-pools { pool-id: pool-id }) err-not-found)))
        (try! (burn-cowcoin amount))
        (map-set insurance-pools
            { pool-id: pool-id }
            (merge pool { 
                total-stake: (+ (get total-stake pool) amount),
                members: (+ (get members pool) u1)
            })
        )
        (ok true)))

(define-public (submit-vet-claim (livestock-id uint) (description (string-ascii 50)) (amount uint))
    (let ((claim-id (var-get next-claim-id)))
        (asserts! (is-livestock-owner livestock-id) err-owner-only)
        (map-insert vet-claims
            { claim-id: claim-id }
            { livestock-id: livestock-id, description: description, amount: amount, status: "pending" }
        )
        (var-set next-claim-id (+ claim-id u1))
        (ok claim-id)))

(define-public (record-reputation-event (livestock-id uint) (event-type (string-ascii 20)) (impact int))
    (let ((event-id (var-get next-event-id))
          (reputation (unwrap! (map-get? livestock-reputation { livestock-id: livestock-id }) err-not-found)))
        (asserts! (is-livestock-owner livestock-id) err-owner-only)
        (map-insert reputation-events
            { event-id: event-id }
            { livestock-id: livestock-id, event-type: event-type, impact: impact, reporter: tx-sender }
        )
        (var-set next-event-id (+ event-id u1))
        (try! (update-reputation-score livestock-id impact))
        (ok event-id)))

(define-public (update-breeding-success (livestock-id uint) (success-count uint))
    (let ((reputation (unwrap! (map-get? livestock-reputation { livestock-id: livestock-id }) err-not-found)))
        (asserts! (is-livestock-owner livestock-id) err-owner-only)
        (map-set livestock-reputation
            { livestock-id: livestock-id }
            (merge reputation { breeding-success: success-count })
        )
        (ok true)))

(define-public (update-productivity-rating (livestock-id uint) (rating uint))
    (let ((reputation (unwrap! (map-get? livestock-reputation { livestock-id: livestock-id }) err-not-found)))
        (asserts! (is-livestock-owner livestock-id) err-owner-only)
        (asserts! (<= rating u100) (err u104))
        (map-set livestock-reputation
            { livestock-id: livestock-id }
            (merge reputation { productivity-rating: rating })
        )
        (ok true)))

(define-public (start-auction (livestock-id uint) (start-price uint) (duration-blocks uint))
    (let ((auction-id (var-get next-auction-id)))
        (asserts! (is-livestock-owner livestock-id) err-owner-only)
        (map-insert livestock-auctions
            { auction-id: auction-id }
            { livestock-id: livestock-id, seller: tx-sender, start-price: start-price, current-bid: start-price, bidder: none, end-block: (+ stacks-block-height duration-blocks) }
        )
        (var-set next-auction-id (+ auction-id u1))
        (ok auction-id)))

(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let ((auction (unwrap! (map-get? livestock-auctions { auction-id: auction-id }) err-auction-not-found)))
        (asserts! (< stacks-block-height (get end-block auction)) err-auction-ended)
        (asserts! (> bid-amount (get current-bid auction)) err-bid-too-low)
        (map-set livestock-auctions
            { auction-id: auction-id }
            (merge auction { current-bid: bid-amount, bidder: (some tx-sender) })
        )
        (ok true)))

(define-public (end-auction (auction-id uint))
    (let ((auction (unwrap! (map-get? livestock-auctions { auction-id: auction-id }) err-auction-not-found))
          (bidder (unwrap! (get bidder auction) err-auction-not-found)))
        (asserts! (>= stacks-block-height (get end-block auction)) err-auction-ended)
        (asserts! (is-eq tx-sender (get seller auction)) err-not-seller)
        (try! (transfer-livestock (get livestock-id auction) bidder))
        (try! (ft-transfer? cowcoin (get current-bid auction) bidder (get seller auction)))
        (map-delete livestock-auctions { auction-id: auction-id })
        (ok true)))

;; Helper Functions
(define-private (mint-cowcoin (livestock-id uint))
    (ft-mint? cowcoin u100 tx-sender))

(define-private (burn-cowcoin (amount uint))
    (ft-burn? cowcoin amount tx-sender))

(define-private (transfer-cowcoin (livestock-id uint) (recipient principal))
    (ft-transfer? cowcoin u100 tx-sender recipient))

(define-private (is-livestock-owner (livestock-id uint))
    (let ((livestock (unwrap! (map-get? livestock-registry { id: livestock-id }) false)))
        (is-eq tx-sender (get owner livestock))))

(define-private (update-reputation-score (livestock-id uint) (impact int))
    (let ((reputation (unwrap! (map-get? livestock-reputation { livestock-id: livestock-id }) err-not-found))
          (current-score (get score reputation))
          (new-score (if (> impact 0)
                         (+ current-score (to-uint impact))
                         (if (> current-score (to-uint (- 0 impact)))
                             (- current-score (to-uint (- 0 impact)))
                             u0))))
        (map-set livestock-reputation
            { livestock-id: livestock-id }
            (merge reputation { 
                score: new-score,
                health-events: (+ (get health-events reputation) u1)
            })
        )
        (ok true)))

(define-read-only (get-livestock-info (livestock-id uint))
    (ok (unwrap! (map-get? livestock-registry { id: livestock-id }) err-not-found)))
(define-read-only (get-pool-info (pool-id uint))
    (ok (unwrap! (map-get? insurance-pools { pool-id: pool-id }) err-not-found)))
(define-read-only (get-claim-info (claim-id uint))
    (ok (unwrap! (map-get? vet-claims { claim-id: claim-id }) err-not-found)))

(define-read-only (get-reputation-info (livestock-id uint))
    (ok (unwrap! (map-get? livestock-reputation { livestock-id: livestock-id }) err-not-found)))

(define-read-only (get-reputation-event (event-id uint))
    (ok (unwrap! (map-get? reputation-events { event-id: event-id }) err-not-found)))

(define-read-only (get-auction-info (auction-id uint))
    (ok (unwrap! (map-get? livestock-auctions { auction-id: auction-id }) err-auction-not-found)))