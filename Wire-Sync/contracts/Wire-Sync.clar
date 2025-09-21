;; Wire Sync - Decentralized Journalism Funding with Impact Metrics
;; A platform for funding journalism with reputation-based impact tracking

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-amount (err u105))

;; Data variables
(define-data-var next-article-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-funding-amount uint u1000000) ;; 1 STX minimum

;; Data maps
(define-map articles
  { article-id: uint }
  {
    journalist: principal,
    title: (string-ascii 100),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    impact-score: uint,
    status: (string-ascii 20), ;; "active", "funded", "completed", "cancelled"
    created-at: uint
  }
)

(define-map journalist-reputation
  { journalist: principal }
  {
    total-articles: uint,
    successful-articles: uint,
    total-funding-raised: uint,
    average-impact-score: uint,
    reputation-score: uint
  }
)

(define-map article-funders
  { article-id: uint, funder: principal }
  {
    amount: uint,
    funded-at: uint
  }
)

(define-map impact-metrics
  { article-id: uint }
  {
    views: uint,
    shares: uint,
    citations: uint,
    verified-sources: uint,
    community-rating: uint,
    last-updated: uint
  }
)

;; Read-only functions
(define-read-only (get-article (article-id uint))
  (map-get? articles { article-id: article-id })
)

(define-read-only (get-journalist-reputation (journalist principal))
  (map-get? journalist-reputation { journalist: journalist })
)

(define-read-only (get-funding-details (article-id uint) (funder principal))
  (map-get? article-funders { article-id: article-id, funder: funder })
)

(define-read-only (get-impact-metrics (article-id uint))
  (map-get? impact-metrics { article-id: article-id })
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (calculate-reputation-score (journalist principal))
  (let (
    (rep-data (default-to 
      { total-articles: u0, successful-articles: u0, total-funding-raised: u0, 
        average-impact-score: u0, reputation-score: u0 }
      (get-journalist-reputation journalist)))
  )
    (if (> (get total-articles rep-data) u0)
      (let (
        (success-rate (* (/ (get successful-articles rep-data) (get total-articles rep-data)) u100))
        (funding-factor (if (> (get total-funding-raised rep-data) u10000000) u50 u0))
        (impact-factor (/ (get average-impact-score rep-data) u10))
      )
        (+ success-rate funding-factor impact-factor)
      )
      u0
    )
  )
)

;; Public functions
(define-public (create-article (title (string-ascii 100)) (funding-goal uint) (deadline uint))
  (let (
    (article-id (var-get next-article-id))
  )
    (asserts! (> funding-goal (var-get min-funding-amount)) err-invalid-amount)
    (asserts! (> deadline stacks-block-height) err-invalid-amount)
    
    ;; Create article
    (map-set articles
      { article-id: article-id }
      {
        journalist: tx-sender,
        title: title,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: deadline,
        impact-score: u0,
        status: "active",
        created-at: stacks-block-height
      }
    )
    
    ;; Initialize impact metrics
    (map-set impact-metrics
      { article-id: article-id }
      {
        views: u0,
        shares: u0,
        citations: u0,
        verified-sources: u0,
        community-rating: u0,
        last-updated: stacks-block-height
      }
    )
    
    ;; Update journalist stats
    (update-journalist-stats tx-sender u1 u0 u0 u0)
    
    ;; Increment next article ID
    (var-set next-article-id (+ article-id u1))
    
    (ok article-id)
  )
)

(define-public (fund-article (article-id uint) (amount uint))
  (let (
    (article (unwrap! (get-article article-id) err-not-found))
    (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
    (funding-amount (- amount platform-fee))
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq (get status article) "active") err-unauthorized)
    (asserts! (< stacks-block-height (get deadline article)) err-unauthorized)
    
    ;; Transfer funds
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update article funding
    (map-set articles
      { article-id: article-id }
      (merge article { current-funding: (+ (get current-funding article) funding-amount) })
    )
    
    ;; Record funder
    (map-set article-funders
      { article-id: article-id, funder: tx-sender }
      {
        amount: (+ funding-amount 
          (default-to u0 (get amount (get-funding-details article-id tx-sender)))),
        funded-at: stacks-block-height
      }
    )
    
    ;; Check if funding goal is reached
    (let ((updated-article (unwrap! (get-article article-id) err-not-found)))
      (if (>= (get current-funding updated-article) (get funding-goal updated-article))
        (begin
          (map-set articles
            { article-id: article-id }
            (merge updated-article { status: "funded" })
          )
          (update-journalist-stats (get journalist article) u0 u1 funding-amount u0)
        )
        true
      )
    )
    
    (ok true)
  )
)

(define-public (update-impact-metrics 
  (article-id uint) 
  (views uint) 
  (shares uint) 
  (citations uint) 
  (verified-sources uint)
  (community-rating uint))
  (let (
    (article (unwrap! (get-article article-id) err-not-found))
  )
    ;; Only journalist or contract owner can update metrics
    (asserts! (or (is-eq tx-sender (get journalist article)) 
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Calculate impact score
    (let (
      (impact-score (+ (* views u1) (* shares u3) (* citations u5) 
                      (* verified-sources u10) (* community-rating u2)))
    )
      ;; Update impact metrics
      (map-set impact-metrics
        { article-id: article-id }
        {
          views: views,
          shares: shares,
          citations: citations,
          verified-sources: verified-sources,
          community-rating: community-rating,
          last-updated: stacks-block-height
        }
      )
      
      ;; Update article impact score
      (map-set articles
        { article-id: article-id }
        (merge article { impact-score: impact-score })
      )
      
      ;; Update journalist reputation if article is completed
      (if (is-eq (get status article) "completed")
        (update-journalist-reputation (get journalist article) impact-score)
        true
      )
      
      (ok impact-score)
    )
  )
)

(define-public (complete-article (article-id uint))
  (let (
    (article (unwrap! (get-article article-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get journalist article)) err-unauthorized)
    (asserts! (is-eq (get status article) "funded") err-unauthorized)
    
    (map-set articles
      { article-id: article-id }
      (merge article { status: "completed" })
    )
    
    (ok true)
  )
)

(define-public (withdraw-funds (article-id uint))
  (let (
    (article (unwrap! (get-article article-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get journalist article)) err-unauthorized)
    (asserts! (is-eq (get status article) "funded") err-unauthorized)
    
    ;; Transfer funds to journalist
    (try! (as-contract (stx-transfer? (get current-funding article) tx-sender (get journalist article))))
    
    (ok true)
  )
)

;; Private functions
(define-private (update-journalist-stats 
  (journalist principal) 
  (new-articles uint) 
  (successful-articles uint) 
  (funding-amount uint) 
  (impact-score uint))
  (let (
    (current-rep (default-to 
      { total-articles: u0, successful-articles: u0, total-funding-raised: u0, 
        average-impact-score: u0, reputation-score: u0 }
      (get-journalist-reputation journalist)))
  )
    (map-set journalist-reputation
      { journalist: journalist }
      {
        total-articles: (+ (get total-articles current-rep) new-articles),
        successful-articles: (+ (get successful-articles current-rep) successful-articles),
        total-funding-raised: (+ (get total-funding-raised current-rep) funding-amount),
        average-impact-score: (get average-impact-score current-rep),
        reputation-score: (calculate-reputation-score journalist)
      }
    )
  )
)

(define-private (update-journalist-reputation (journalist principal) (impact-score uint))
  (let (
    (current-rep (unwrap! (get-journalist-reputation journalist) false))
    (total-completed (+ (get successful-articles current-rep) u1))
    (current-avg (get average-impact-score current-rep))
    (new-avg (/ (+ (* current-avg (- total-completed u1)) impact-score) total-completed))
  )
    (map-set journalist-reputation
      { journalist: journalist }
      (merge current-rep { 
        average-impact-score: new-avg,
        reputation-score: (calculate-reputation-score journalist)
      })
    )
    true
  )
)

;; Admin functions
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (set-min-funding-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-funding-amount new-amount)
    (ok true)
  )
)