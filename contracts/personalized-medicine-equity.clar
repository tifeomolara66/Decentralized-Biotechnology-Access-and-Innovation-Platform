;; Personalized Medicine Equity Contract
;; Prevents genetic-based healthcare from increasing health disparities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-STUDY-NOT-FOUND (err u402))
(define-constant ERR-TREATMENT-NOT-FOUND (err u403))
(define-constant ERR-INSUFFICIENT-DIVERSITY (err u404))
(define-constant ERR-ACCESS-DENIED (err u405))

;; Data Variables
(define-data-var next-study-id uint u1)
(define-data-var next-treatment-id uint u1)
(define-data-var min-diversity-score uint u70) ;; Minimum diversity requirement
(define-data-var equity-fund-balance uint u0)

;; Data Maps
(define-map genetic-studies
  uint
  {
    researcher: principal,
    study-name: (string-ascii 100),
    target-population: uint,
    diversity-requirements: {
      african: uint,
      asian: uint,
      european: uint,
      hispanic: uint,
      native-american: uint,
      other: uint
    },
    current-enrollment: {
      african: uint,
      asian: uint,
      european: uint,
      hispanic: uint,
      native-american: uint,
      other: uint
    },
    study-status: (string-ascii 20), ;; "recruiting", "active", "completed"
    diversity-score: uint,
    approved: bool
  }
)

(define-map personalized-treatments
  uint
  {
    provider: principal,
    treatment-name: (string-ascii 100),
    genetic-markers: (list 10 (string-ascii 50)),
    base-cost: uint,
    populations-tested: (list 6 (string-ascii 20)),
    efficacy-data: {
      african: uint,
      asian: uint,
      european: uint,
      hispanic: uint,
      native-american: uint,
      other: uint
    },
    equity-tier: uint, ;; 1-5, where 1 is most equitable
    subsidized: bool
  }
)

(define-map patient-genetic-profiles
  principal
  {
    ancestry: (string-ascii 20),
    genetic-markers: (list 20 (string-ascii 50)),
    verified: bool,
    privacy-level: uint, ;; 1-5, where 5 is most private
    consent-research: bool
  }
)

(define-map treatment-access-records
  { patient: principal, treatment-id: uint }
  {
    access-granted: bool,
    subsidy-applied: uint,
    access-date: uint,
    outcome-reported: bool
  }
)

(define-map authorized-researchers
  principal
  bool
)

(define-map equity-fund-contributors
  principal
  uint
)

;; Authorization Functions
(define-public (add-authorized-researcher (researcher principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-researchers researcher true))
  )
)

;; Patient Profile Management
(define-public (register-genetic-profile
  (ancestry (string-ascii 20))
  (genetic-markers (list 20 (string-ascii 50)))
  (privacy-level uint)
  (consent-research bool))
  (begin
    (asserts! (> (len ancestry) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= privacy-level u1) (<= privacy-level u5)) ERR-INVALID-INPUT)

    (map-set patient-genetic-profiles tx-sender
      {
        ancestry: ancestry,
        genetic-markers: genetic-markers,
        verified: false,
        privacy-level: privacy-level,
        consent-research: consent-research
      }
    )
    (ok true)
  )
)

(define-public (verify-genetic-profile (patient principal))
  (let
    (
      (profile (unwrap! (map-get? patient-genetic-profiles patient) ERR-INVALID-INPUT))
      (is-authorized (default-to false (map-get? authorized-researchers tx-sender)))
    )
    (asserts! is-authorized ERR-NOT-AUTHORIZED)

    (map-set patient-genetic-profiles patient
      (merge profile { verified: true })
    )
    (ok true)
  )
)

;; Study Management
(define-public (create-genetic-study
  (study-name (string-ascii 100))
  (target-population uint)
  (diversity-requirements {
    african: uint,
    asian: uint,
    european: uint,
    hispanic: uint,
    native-american: uint,
    other: uint
  }))
  (let
    (
      (study-id (var-get next-study-id))
      (is-authorized (default-to false (map-get? authorized-researchers tx-sender)))
      (total-required (+ (+ (+ (get african diversity-requirements) (get asian diversity-requirements))
                           (+ (get european diversity-requirements) (get hispanic diversity-requirements)))
                        (+ (get native-american diversity-requirements) (get other diversity-requirements))))
    )
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    (asserts! (> (len study-name) u0) ERR-INVALID-INPUT)
    (asserts! (> target-population u0) ERR-INVALID-INPUT)
    (asserts! (is-eq total-required target-population) ERR-INVALID-INPUT)

    (map-set genetic-studies study-id
      {
        researcher: tx-sender,
        study-name: study-name,
        target-population: target-population,
        diversity-requirements: diversity-requirements,
        current-enrollment: {
          african: u0,
          asian: u0,
          european: u0,
          hispanic: u0,
          native-american: u0,
          other: u0
        },
        study-status: "recruiting",
        diversity-score: u0,
        approved: false
      }
    )

    (var-set next-study-id (+ study-id u1))
    (ok study-id)
  )
)

(define-public (enroll-in-study (study-id uint))
  (let
    (
      (study (unwrap! (map-get? genetic-studies study-id) ERR-STUDY-NOT-FOUND))
      (patient-profile (unwrap! (map-get? patient-genetic-profiles tx-sender) ERR-INVALID-INPUT))
      (ancestry (get ancestry patient-profile))
    )
    (asserts! (get verified patient-profile) ERR-NOT-AUTHORIZED)
    (asserts! (get consent-research patient-profile) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get study-status study) "recruiting") ERR-INVALID-INPUT)

    ;; Update enrollment based on ancestry
    (let
      (
        (current-enrollment (get current-enrollment study))
        (updated-enrollment (update-enrollment-by-ancestry current-enrollment ancestry))
      )
      (map-set genetic-studies study-id
        (merge study {
          current-enrollment: updated-enrollment,
          diversity-score: (calculate-diversity-score
            (get diversity-requirements study)
            updated-enrollment)
        })
      )
    )

    (ok true)
  )
)

(define-private (update-enrollment-by-ancestry (current {
  african: uint,
  asian: uint,
  european: uint,
  hispanic: uint,
  native-american: uint,
  other: uint
}) (ancestry (string-ascii 20)))
  (if (is-eq ancestry "african")
    (merge current { african: (+ (get african current) u1) })
    (if (is-eq ancestry "asian")
      (merge current { asian: (+ (get asian current) u1) })
      (if (is-eq ancestry "european")
        (merge current { european: (+ (get european current) u1) })
        (if (is-eq ancestry "hispanic")
          (merge current { hispanic: (+ (get hispanic current) u1) })
          (if (is-eq ancestry "native-american")
            (merge current { native-american: (+ (get native-american current) u1) })
            (merge current { other: (+ (get other current) u1) })
          )
        )
      )
    )
  )
)

(define-private (calculate-diversity-score (required {
  african: uint,
  asian: uint,
  european: uint,
  hispanic: uint,
  native-american: uint,
  other: uint
}) (current {
  african: uint,
  asian: uint,
  european: uint,
  hispanic: uint,
  native-american: uint,
  other: uint
}))
  (let
    (
      (african-score (if (> (get african required) u0)
        (/ (* (get african current) u100) (get african required)) u100))
      (asian-score (if (> (get asian required) u0)
        (/ (* (get asian current) u100) (get asian required)) u100))
      (european-score (if (> (get european required) u0)
        (/ (* (get european current) u100) (get european required)) u100))
      (hispanic-score (if (> (get hispanic required) u0)
        (/ (* (get hispanic current) u100) (get hispanic required)) u100))
      (native-score (if (> (get native-american required) u0)
        (/ (* (get native-american current) u100) (get native-american required)) u100))
      (other-score (if (> (get other required) u0)
        (/ (* (get other current) u100) (get other required)) u100))
    )
    (/ (+ african-score (+ asian-score (+ european-score (+ hispanic-score (+ native-score other-score))))) u6)
  )
)

;; Treatment Registration
(define-public (register-personalized-treatment
  (treatment-name (string-ascii 100))
  (genetic-markers (list 10 (string-ascii 50)))
  (base-cost uint)
  (populations-tested (list 6 (string-ascii 20)))
  (efficacy-data {
    african: uint,
    asian: uint,
    european: uint,
    hispanic: uint,
    native-american: uint,
    other: uint
  }))
  (let
    (
      (treatment-id (var-get next-treatment-id))
      (equity-tier (calculate-equity-tier efficacy-data populations-tested))
      (is-authorized (default-to false (map-get? authorized-researchers tx-sender)))
    )
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    (asserts! (> (len treatment-name) u0) ERR-INVALID-INPUT)
    (asserts! (> base-cost u0) ERR-INVALID-INPUT)
    (asserts! (>= (len populations-tested) u3) ERR-INSUFFICIENT-DIVERSITY) ;; Minimum 3 populations

    (map-set personalized-treatments treatment-id
      {
        provider: tx-sender,
        treatment-name: treatment-name,
        genetic-markers: genetic-markers,
        base-cost: base-cost,
        populations-tested: populations-tested,
        efficacy-data: efficacy-data,
        equity-tier: equity-tier,
        subsidized: (>= equity-tier u4) ;; Tier 4-5 treatments get subsidies
      }
    )

    (var-set next-treatment-id (+ treatment-id u1))
    (ok treatment-id)
  )
)

(define-private (calculate-equity-tier (efficacy-data {
  african: uint,
  asian: uint,
  european: uint,
  hispanic: uint,
  native-american: uint,
  other: uint
}) (populations-tested (list 6 (string-ascii 20))))
  (let
    (
      (avg-efficacy (/ (+ (get african efficacy-data)
                         (+ (get asian efficacy-data)
                           (+ (get european efficacy-data)
                             (+ (get hispanic efficacy-data)
                               (+ (get native-american efficacy-data)
                                 (get other efficacy-data)))))) u6))
      (population-count (len populations-tested))
    )
    (if (and (>= avg-efficacy u80) (>= population-count u5))
      u1 ;; Highest equity tier
      (if (and (>= avg-efficacy u70) (>= population-count u4))
        u2
        (if (and (>= avg-efficacy u60) (>= population-count u3))
          u3
          (if (>= avg-efficacy u50)
            u4
            u5 ;; Lowest equity tier
          )
        )
      )
    )
  )
)

;; Treatment Access
(define-public (request-treatment-access (treatment-id uint))
  (let
    (
      (treatment (unwrap! (map-get? personalized-treatments treatment-id) ERR-TREATMENT-NOT-FOUND))
      (patient-profile (unwrap! (map-get? patient-genetic-profiles tx-sender) ERR-INVALID-INPUT))
      (subsidy-amount (calculate-subsidy treatment-id (get ancestry patient-profile)))
    )
    (asserts! (get verified patient-profile) ERR-NOT-AUTHORIZED)

    (map-set treatment-access-records { patient: tx-sender, treatment-id: treatment-id }
      {
        access-granted: true,
        subsidy-applied: subsidy-amount,
        access-date: block-height,
        outcome-reported: false
      }
    )

    (ok subsidy-amount)
  )
)

(define-private (calculate-subsidy (treatment-id uint) (ancestry (string-ascii 20)))
  (let
    (
      (treatment (unwrap-panic (map-get? personalized-treatments treatment-id)))
      (base-cost (get base-cost treatment))
      (equity-tier (get equity-tier treatment))
    )
    (if (get subsidized treatment)
      (if (>= equity-tier u4)
        (/ (* base-cost u50) u100) ;; 50% subsidy for tier 4-5
        (/ (* base-cost u25) u100) ;; 25% subsidy for tier 1-3
      )
      u0
    )
  )
)

;; Equity Fund Management
(define-public (contribute-to-equity-fund (amount uint))
  (let
    (
      (current-contribution (default-to u0 (map-get? equity-fund-contributors tx-sender)))
    )
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (var-set equity-fund-balance (+ (var-get equity-fund-balance) amount))
    (map-set equity-fund-contributors tx-sender (+ current-contribution amount))

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-genetic-study (study-id uint))
  (map-get? genetic-studies study-id)
)

(define-read-only (get-personalized-treatment (treatment-id uint))
  (map-get? personalized-treatments treatment-id)
)

(define-read-only (get-patient-profile (patient principal))
  (map-get? patient-genetic-profiles patient)
)

(define-read-only (get-treatment-access (patient principal) (treatment-id uint))
  (map-get? treatment-access-records { patient: patient, treatment-id: treatment-id })
)

(define-read-only (get-equity-fund-balance)
  (var-get equity-fund-balance)
)

(define-read-only (is-authorized-researcher (researcher principal))
  (default-to false (map-get? authorized-researchers researcher))
)

(define-read-only (calculate-treatment-cost (treatment-id uint) (patient principal))
  (match (map-get? personalized-treatments treatment-id)
    treatment (match (map-get? patient-genetic-profiles patient)
      profile (let
        (
          (base-cost (get base-cost treatment))
          (subsidy (calculate-subsidy treatment-id (get ancestry profile)))
        )
        (some (- base-cost subsidy))
      )
      none
    )
    none
  )
)
