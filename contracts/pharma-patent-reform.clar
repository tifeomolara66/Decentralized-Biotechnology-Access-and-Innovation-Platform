;; Pharmaceutical Patent Reform Contract
;; Balances innovation incentives with affordable medicine access

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-INPUT (err u201))
(define-constant ERR-PATENT-NOT-FOUND (err u202))
(define-constant ERR-PATENT-EXPIRED (err u203))
(define-constant ERR-INSUFFICIENT-FUNDS (err u204))
(define-constant ERR-LICENSE-EXISTS (err u205))

;; Data Variables
(define-data-var next-patent-id uint u1)
(define-data-var next-license-id uint u1)
(define-data-var base-patent-term uint u5256000) ;; ~10 years in blocks
(define-data-var compulsory-license-threshold uint u1000000) ;; Price threshold in microSTX

;; Data Maps
(define-map patents
  uint
  {
    holder: principal,
    drug-name: (string-ascii 100),
    development-cost: uint,
    social-impact-score: uint, ;; 1-100 scale
    base-price: uint,
    registration-block: uint,
    patent-term: uint,
    active: bool,
    compulsory-licensed: bool
  }
)

(define-map compulsory-licenses
  uint
  {
    patent-id: uint,
    licensee: principal,
    royalty-rate: uint, ;; Basis points (e.g., 500 = 5%)
    issue-date: uint,
    justification: (string-ascii 200)
  }
)

(define-map patent-renewals
  uint
  {
    patent-id: uint,
    renewal-count: uint,
    last-renewal-block: uint,
    total-revenue: uint
  }
)

(define-map authorized-evaluators
  principal
  bool
)

;; Authorization Functions
(define-public (add-authorized-evaluator (evaluator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-evaluators evaluator true))
  )
)

;; Patent Registration
(define-public (register-patent
  (drug-name (string-ascii 100))
  (development-cost uint)
  (social-impact-score uint)
  (base-price uint))
  (let
    (
      (patent-id (var-get next-patent-id))
      (calculated-term (calculate-patent-term development-cost social-impact-score))
    )
    (asserts! (> development-cost u0) ERR-INVALID-INPUT)
    (asserts! (and (>= social-impact-score u1) (<= social-impact-score u100)) ERR-INVALID-INPUT)
    (asserts! (> base-price u0) ERR-INVALID-INPUT)

    (map-set patents patent-id
      {
        holder: tx-sender,
        drug-name: drug-name,
        development-cost: development-cost,
        social-impact-score: social-impact-score,
        base-price: base-price,
        registration-block: block-height,
        patent-term: calculated-term,
        active: true,
        compulsory-licensed: false
      }
    )

    (map-set patent-renewals patent-id
      {
        patent-id: patent-id,
        renewal-count: u0,
        last-renewal-block: block-height,
        total-revenue: u0
      }
    )

    (var-set next-patent-id (+ patent-id u1))
    (ok patent-id)
  )
)

;; Patent Term Calculation
(define-private (calculate-patent-term (development-cost uint) (social-impact-score uint))
  (let
    (
      (base-term (var-get base-patent-term))
      (cost-multiplier (calculate-cost-multiplier development-cost))
      (impact-multiplier (calculate-impact-multiplier social-impact-score))
    )
    (/ (* base-term (* cost-multiplier impact-multiplier)) u10000)
  )
)

(define-private (calculate-cost-multiplier (development-cost uint))
  (if (< development-cost u50000000) ;; < 50M microSTX
    u8000 ;; 0.8x multiplier
    (if (< development-cost u100000000) ;; < 100M microSTX
      u10000 ;; 1.0x multiplier
      (if (< development-cost u200000000) ;; < 200M microSTX
        u12000 ;; 1.2x multiplier
        u15000 ;; 1.5x multiplier for very high costs
      )
    )
  )
)

(define-private (calculate-impact-multiplier (social-impact-score uint))
  (if (>= social-impact-score u80) ;; High social impact
    u8000 ;; 0.8x multiplier (shorter term for high impact)
    (if (>= social-impact-score u60)
      u10000 ;; 1.0x multiplier
      (if (>= social-impact-score u40)
        u12000 ;; 1.2x multiplier
        u15000 ;; 1.5x multiplier for low social impact
      )
    )
  )
)

;; Compulsory Licensing
(define-public (issue-compulsory-license
  (patent-id uint)
  (licensee principal)
  (justification (string-ascii 200)))
  (let
    (
      (patent (unwrap! (map-get? patents patent-id) ERR-PATENT-NOT-FOUND))
      (license-id (var-get next-license-id))
      (is-authorized (default-to false (map-get? authorized-evaluators tx-sender)))
      (royalty-rate (calculate-compulsory-royalty-rate patent-id))
    )
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    (asserts! (get active patent) ERR-PATENT-EXPIRED)
    (asserts! (not (get compulsory-licensed patent)) ERR-LICENSE-EXISTS)
    (asserts! (>= (get base-price patent) (var-get compulsory-license-threshold)) ERR-INVALID-INPUT)

    ;; Mark patent as compulsory licensed
    (map-set patents patent-id
      (merge patent { compulsory-licensed: true })
    )

    ;; Create compulsory license
    (map-set compulsory-licenses license-id
      {
        patent-id: patent-id,
        licensee: licensee,
        royalty-rate: royalty-rate,
        issue-date: block-height,
        justification: justification
      }
    )

    (var-set next-license-id (+ license-id u1))
    (ok license-id)
  )
)

(define-private (calculate-compulsory-royalty-rate (patent-id uint))
  (let
    (
      (patent (unwrap-panic (map-get? patents patent-id)))
      (social-impact (get social-impact-score patent))
    )
    (if (>= social-impact u80)
      u200 ;; 2% for high social impact
      (if (>= social-impact u60)
        u300 ;; 3%
        (if (>= social-impact u40)
          u400 ;; 4%
          u500 ;; 5% for low social impact
        )
      )
    )
  )
)

;; Patent Renewal
(define-public (renew-patent (patent-id uint) (revenue-report uint))
  (let
    (
      (patent (unwrap! (map-get? patents patent-id) ERR-PATENT-NOT-FOUND))
      (renewal-info (unwrap! (map-get? patent-renewals patent-id) ERR-PATENT-NOT-FOUND))
      (blocks-since-registration (- block-height (get registration-block patent)))
    )
    (asserts! (is-eq tx-sender (get holder patent)) ERR-NOT-AUTHORIZED)
    (asserts! (get active patent) ERR-PATENT-EXPIRED)
    (asserts! (< blocks-since-registration (get patent-term patent)) ERR-PATENT-EXPIRED)

    ;; Update renewal information
    (map-set patent-renewals patent-id
      {
        patent-id: patent-id,
        renewal-count: (+ (get renewal-count renewal-info) u1),
        last-renewal-block: block-height,
        total-revenue: (+ (get total-revenue renewal-info) revenue-report)
      }
    )

    (ok true)
  )
)

;; Patent Expiration
(define-public (expire-patent (patent-id uint))
  (let
    (
      (patent (unwrap! (map-get? patents patent-id) ERR-PATENT-NOT-FOUND))
      (blocks-since-registration (- block-height (get registration-block patent)))
    )
    (asserts! (>= blocks-since-registration (get patent-term patent)) ERR-INVALID-INPUT)

    (map-set patents patent-id
      (merge patent { active: false })
    )

    (ok true)
  )
)

;; Royalty Payment
(define-public (pay-royalty (license-id uint) (sales-amount uint))
  (let
    (
      (license (unwrap! (map-get? compulsory-licenses license-id) ERR-INVALID-INPUT))
      (patent-id (get patent-id license))
      (patent (unwrap! (map-get? patents patent-id) ERR-PATENT-NOT-FOUND))
      (royalty-amount (/ (* sales-amount (get royalty-rate license)) u10000))
    )
    (asserts! (is-eq tx-sender (get licensee license)) ERR-NOT-AUTHORIZED)
    (asserts! (get active patent) ERR-PATENT-EXPIRED)

    ;; Transfer royalty to patent holder
    (try! (stx-transfer? royalty-amount tx-sender (get holder patent)))

    (ok royalty-amount)
  )
)

;; Read-only Functions
(define-read-only (get-patent (patent-id uint))
  (map-get? patents patent-id)
)

(define-read-only (get-compulsory-license (license-id uint))
  (map-get? compulsory-licenses license-id)
)

(define-read-only (get-patent-renewal-info (patent-id uint))
  (map-get? patent-renewals patent-id)
)

(define-read-only (is-patent-active (patent-id uint))
  (match (map-get? patents patent-id)
    patent (and
      (get active patent)
      (< (- block-height (get registration-block patent)) (get patent-term patent))
    )
    false
  )
)

(define-read-only (calculate-patent-term-preview (development-cost uint) (social-impact-score uint))
  (calculate-patent-term development-cost social-impact-score)
)

(define-read-only (get-compulsory-license-threshold)
  (var-get compulsory-license-threshold)
)
