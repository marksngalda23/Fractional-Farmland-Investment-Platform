(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-POOL-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-FUNDS (err u400))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-POOL-INACTIVE (err u403))
(define-constant ERR-ALREADY-EXISTS (err u409))

(define-data-var pool-counter uint u0)
(define-data-var total-yield-distributed uint u0)

(define-map farmland-pools
  uint
  {
    owner: principal,
    location: (string-ascii 100),
    total-value: uint,
    funds-raised: uint,
    target-amount: uint,
    yield-rate: uint,
    active: bool,
    created-at: uint
  }
)

(define-map investor-shares
  { pool-id: uint, investor: principal }
  {
    shares: uint,
    invested-amount: uint,
    yield-claimed: uint,
    joined-at: uint
  }
)

(define-map pool-investors
  uint
  (list 200 principal)
)

(define-map yield-tokens
  principal
  uint
)

(define-read-only (get-pool (pool-id uint))
  (map-get? farmland-pools pool-id)
)

(define-read-only (get-investor-shares (pool-id uint) (investor principal))
  (map-get? investor-shares { pool-id: pool-id, investor: investor })
)

(define-read-only (get-yield-tokens (investor principal))
  (default-to u0 (map-get? yield-tokens investor))
)

(define-read-only (get-pool-count)
  (var-get pool-counter)
)

(define-read-only (get-total-yield-distributed)
  (var-get total-yield-distributed)
)

(define-public (create-farmland-pool (location (string-ascii 100)) (target-amount uint) (yield-rate uint))
  (let ((pool-id (+ (var-get pool-counter) u1)))
    (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> yield-rate u0) ERR-INVALID-AMOUNT)
    (map-set farmland-pools
      pool-id
      {
        owner: tx-sender,
        location: location,
        total-value: target-amount,
        funds-raised: u0,
        target-amount: target-amount,
        yield-rate: yield-rate,
        active: true,
        created-at: stacks-block-height
      }
    )
    (var-set pool-counter pool-id)
    (ok pool-id)
  )
)

(define-public (invest-in-pool (pool-id uint) (amount uint))
  (let (
    (pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND))
    (current-shares (get shares (default-to { shares: u0, invested-amount: u0, yield-claimed: u0, joined-at: u0 } 
                                           (get-investor-shares pool-id tx-sender))))
    (new-funds-raised (+ (get funds-raised pool-data) amount))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (get active pool-data) ERR-POOL-INACTIVE)
    (asserts! (<= new-funds-raised (get target-amount pool-data)) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (let ((new-shares (+ current-shares amount)))
      (map-set investor-shares
        { pool-id: pool-id, investor: tx-sender }
        {
          shares: new-shares,
          invested-amount: (+ (get invested-amount 
                                   (default-to { shares: u0, invested-amount: u0, yield-claimed: u0, joined-at: u0 } 
                                              (get-investor-shares pool-id tx-sender))) amount),
          yield-claimed: (get yield-claimed 
                             (default-to { shares: u0, invested-amount: u0, yield-claimed: u0, joined-at: u0 } 
                                        (get-investor-shares pool-id tx-sender))),
          joined-at: stacks-block-height
        }
      )
      
      (map-set farmland-pools
        pool-id
        (merge pool-data { funds-raised: new-funds-raised })
      )
      
      (add-to-pool-investors pool-id tx-sender)
      (ok new-shares)
    )
  )
)

(define-private (add-to-pool-investors (pool-id uint) (investor principal))
  (let ((current-investors (default-to (list) (map-get? pool-investors pool-id))))
    (if (is-none (index-of current-investors investor))
      (map-set pool-investors pool-id (unwrap-panic (as-max-len? (append current-investors investor) u200)))
      true
    )
  )
)

(define-public (distribute-yield (pool-id uint) (total-yield uint))
  (let ((pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner pool-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active pool-data) ERR-POOL-INACTIVE)
    (asserts! (> total-yield u0) ERR-INVALID-AMOUNT)
    (asserts! (> (get funds-raised pool-data) u0) ERR-INSUFFICIENT-FUNDS)
    
    (var-set total-yield-distributed (+ (var-get total-yield-distributed) total-yield))
    (distribute-to-investors pool-id total-yield (get funds-raised pool-data))
  )
)

(define-private (distribute-to-investors (pool-id uint) (total-yield uint) (total-funds uint))
  (let ((investors (default-to (list) (map-get? pool-investors pool-id))))
    (fold distribute-to-single-investor investors 
          { pool-id: pool-id, total-yield: total-yield, total-funds: total-funds })
    (ok true)
  )
)

(define-private (distribute-to-single-investor 
  (investor principal) 
  (data { pool-id: uint, total-yield: uint, total-funds: uint }))
  (let (
    (pool-id (get pool-id data))
    (total-yield (get total-yield data))
    (total-funds (get total-funds data))
    (investor-data (unwrap-panic (get-investor-shares pool-id investor)))
    (investor-yield (/ (* total-yield (get shares investor-data)) total-funds))
  )
    (mint-yield-tokens investor investor-yield)
    data
  )
)

(define-private (mint-yield-tokens (investor principal) (amount uint))
  (let ((current-balance (get-yield-tokens investor)))
    (map-set yield-tokens investor (+ current-balance amount))
    true
  )
)

(define-public (claim-yield-tokens)
  (let ((balance (get-yield-tokens tx-sender)))
    (asserts! (> balance u0) ERR-INSUFFICIENT-FUNDS)
    (map-delete yield-tokens tx-sender)
    (as-contract (stx-transfer? balance tx-sender tx-sender))
  )
)

(define-public (withdraw-investment (pool-id uint) (amount uint))
  (let (
    (pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND))
    (investor-data (unwrap! (get-investor-shares pool-id tx-sender) ERR-NOT-AUTHORIZED))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get shares investor-data) amount) ERR-INSUFFICIENT-FUNDS)
    
    (let ((remaining-shares (- (get shares investor-data) amount)))
      (if (is-eq remaining-shares u0)
        (map-delete investor-shares { pool-id: pool-id, investor: tx-sender })
        (map-set investor-shares
          { pool-id: pool-id, investor: tx-sender }
          (merge investor-data { shares: remaining-shares })
        )
      )
      
      (map-set farmland-pools
        pool-id
        (merge pool-data { funds-raised: (- (get funds-raised pool-data) amount) })
      )
      
      (as-contract (stx-transfer? amount tx-sender tx-sender))
    )
  )
)

(define-public (deactivate-pool (pool-id uint))
  (let ((pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner pool-data)) ERR-NOT-AUTHORIZED)
    (map-set farmland-pools
      pool-id
      (merge pool-data { active: false })
    )
    (ok true)
  )
)


(define-map investor-performance
  principal
  {
    total-invested: uint,
    total-withdrawn: uint,
    total-yield-earned: uint,
    pools-participated: uint,
    last-activity: uint
  }
)

(define-read-only (get-investor-performance (investor principal))
  (default-to 
    { 
      total-invested: u0, 
      total-withdrawn: u0, 
      total-yield-earned: u0, 
      pools-participated: u0, 
      last-activity: u0 
    }
    (map-get? investor-performance investor)
  )
)

(define-read-only (calculate-investor-roi (investor principal))
  (let (
    (perf-data (get-investor-performance investor))
    (total-invested (get total-invested perf-data))
    (total-yield-earned (get total-yield-earned perf-data))
  )
    (if (is-eq total-invested u0)
      (ok u0)
      (ok (/ (* total-yield-earned u10000) total-invested))
    )
  )
)

(define-read-only (get-investor-portfolio-value (investor principal))
  (let (
    (perf-data (get-investor-performance investor))
    (total-invested (get total-invested perf-data))
    (total-withdrawn (get total-withdrawn perf-data))
    (total-yield-earned (get total-yield-earned perf-data))
  )
    (ok (+ (- total-invested total-withdrawn) total-yield-earned))
  )
)

(define-private (update-performance-on-invest (investor principal) (amount uint) (is-new-pool bool))
  (let (
    (current-perf (get-investor-performance investor))
    (new-total-invested (+ (get total-invested current-perf) amount))
    (new-pools-count (if is-new-pool 
                       (+ (get pools-participated current-perf) u1)
                       (get pools-participated current-perf)))
  )
    (map-set investor-performance
      investor
      {
        total-invested: new-total-invested,
        total-withdrawn: (get total-withdrawn current-perf),
        total-yield-earned: (get total-yield-earned current-perf),
        pools-participated: new-pools-count,
        last-activity: stacks-block-height
      }
    )
    true
  )
)

(define-private (update-performance-on-yield (investor principal) (yield-amount uint))
  (let ((current-perf (get-investor-performance investor)))
    (map-set investor-performance
      investor
      (merge current-perf 
        { 
          total-yield-earned: (+ (get total-yield-earned current-perf) yield-amount),
          last-activity: stacks-block-height
        }
      )
    )
    true
  )
)


(define-map pool-milestones
  { pool-id: uint, milestone-id: uint }
  {
    target-percentage: uint,
    bonus-percentage: uint,
    reached: bool,
    reached-at: uint
  }
)

(define-map pool-milestone-count
  uint
  uint
)

(define-read-only (get-pool-milestone (pool-id uint) (milestone-id uint))
  (map-get? pool-milestones { pool-id: pool-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (pool-id uint))
  (default-to u0 (map-get? pool-milestone-count pool-id))
)

(define-read-only (get-pool-funding-progress (pool-id uint))
  (let ((pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND)))
    (ok (/ (* (get funds-raised pool-data) u10000) (get target-amount pool-data)))
  )
)

(define-public (create-milestone (pool-id uint) (target-percentage uint) (bonus-percentage uint))
  (let (
    (pool-data (unwrap! (get-pool pool-id) ERR-POOL-NOT-FOUND))
    (milestone-count (get-milestone-count pool-id))
    (new-milestone-id (+ milestone-count u1))
  )
    (asserts! (is-eq tx-sender (get owner pool-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= target-percentage u10000) ERR-INVALID-AMOUNT)
    (asserts! (<= bonus-percentage u10000) ERR-INVALID-AMOUNT)
    (map-set pool-milestones
      { pool-id: pool-id, milestone-id: new-milestone-id }
      {
        target-percentage: target-percentage,
        bonus-percentage: bonus-percentage,
        reached: false,
        reached-at: u0
      }
    )
    (map-set pool-milestone-count pool-id new-milestone-id)
    (ok new-milestone-id)
  )
)

(define-private (check-single-milestone (pool-id uint) (progress uint) (milestone-id uint))
  (match (get-pool-milestone pool-id milestone-id)
    milestone-data
      (if (and (>= progress (get target-percentage milestone-data)) (not (get reached milestone-data)))
        (map-set pool-milestones
          { pool-id: pool-id, milestone-id: milestone-id }
          (merge milestone-data { reached: true, reached-at: stacks-block-height })
        )
        true
      )
    true
  )
)