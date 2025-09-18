;; Coopsave Savings Escrow Contract
;; Manages fund deposits, storage, and consensus-based withdrawals
;; Implements voting mechanisms for democratic fund release

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-GROUP-NOT-FOUND (err u201))
(define-constant ERR-INSUFFICIENT-FUNDS (err u202))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u203))
(define-constant ERR-ALREADY-VOTED (err u204))
(define-constant ERR-VOTING-CLOSED (err u205))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u206))
(define-constant ERR-INVALID-AMOUNT (err u207))
(define-constant ERR-CONSENSUS-NOT-REACHED (err u208))
(define-constant ERR-MINIMUM-CONTRIBUTION (err u209))

;; Data structures
(define-map group-escrows
    { group-id: uint }
    {
        total-balance: uint,
        total-contributions: uint,
        total-withdrawals: uint,
        last-activity: uint,
        is-active: bool,
        member-count: uint
    }
)

(define-map member-contributions
    { group-id: uint, member: principal }
    {
        total-contributed: uint,
        last-contribution: uint,
        contribution-count: uint,
        is-active: bool
    }
)

(define-map withdrawal-proposals
    { group-id: uint, proposal-id: uint }
    {
        proposer: principal,
        amount: uint,
        recipient: principal,
        description: (string-ascii 200),
        created-at: uint,
        voting-ends-at: uint,
        votes-for: uint,
        votes-against: uint,
        total-voters: uint,
        status: (string-ascii 20),
        executed-at: uint
    }
)

(define-map proposal-votes
    { group-id: uint, proposal-id: uint, voter: principal }
    {
        vote: bool,
        voted-at: uint,
        voting-power: uint
    }
)

(define-map group-proposal-counters
    { group-id: uint }
    {
        next-proposal-id: uint,
        total-proposals: uint,
        executed-proposals: uint
    }
)

;; Data variables
(define-data-var contract-paused bool false)
(define-data-var minimum-contribution uint u1000000) ;; 1 STX
(define-data-var platform-fee-rate uint u100) ;; 1% = 100 basis points

;; Public functions

;; Initialize group escrow (called when group is created)
(define-public (initialize-group-escrow (group-id uint) (member-count uint))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? group-escrows { group-id: group-id })) ERR-NOT-AUTHORIZED)
        
        ;; Initialize escrow
        (map-set group-escrows
            { group-id: group-id }
            {
                total-balance: u0,
                total-contributions: u0,
                total-withdrawals: u0,
                last-activity: stacks-block-height,
                is-active: true,
                member-count: member-count
            }
        )
        
        ;; Initialize proposal counter
        (map-set group-proposal-counters
            { group-id: group-id }
            {
                next-proposal-id: u1,
                total-proposals: u0,
                executed-proposals: u0
            }
        )
        
        (ok true)
    )
)

;; Contribute funds to group escrow
(define-public (contribute-funds (group-id uint) (amount uint))
    (let
        (
            (contributor tx-sender)
            (escrow (unwrap! (map-get? group-escrows { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (current-contribution (default-to 
                { total-contributed: u0, last-contribution: u0, contribution-count: u0, is-active: true }
                (map-get? member-contributions { group-id: group-id, member: contributor })
            ))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active escrow) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount (var-get minimum-contribution)) ERR-MINIMUM-CONTRIBUTION)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount contributor (as-contract tx-sender)))
        
        ;; Update member contribution
        (map-set member-contributions
            { group-id: group-id, member: contributor }
            {
                total-contributed: (+ (get total-contributed current-contribution) amount),
                last-contribution: stacks-block-height,
                contribution-count: (+ (get contribution-count current-contribution) u1),
                is-active: true
            }
        )
        
        ;; Update group escrow
        (map-set group-escrows
            { group-id: group-id }
            {
                total-balance: (+ (get total-balance escrow) amount),
                total-contributions: (+ (get total-contributions escrow) amount),
                total-withdrawals: (get total-withdrawals escrow),
                last-activity: stacks-block-height,
                is-active: true,
                member-count: (get member-count escrow)
            }
        )
        
        (ok amount)
    )
)

;; Create withdrawal proposal
(define-public (create-withdrawal-proposal 
    (group-id uint) 
    (amount uint) 
    (recipient principal) 
    (description (string-ascii 200))
    (voting-period uint)
)
    (let
        (
            (proposer tx-sender)
            (escrow (unwrap! (map-get? group-escrows { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (counter (unwrap! (map-get? group-proposal-counters { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (proposal-id (get next-proposal-id counter))
            (voting-ends-at (+ stacks-block-height voting-period))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active escrow) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (get total-balance escrow)) ERR-INSUFFICIENT-FUNDS)
        (asserts! (> (len description) u0) ERR-INVALID-AMOUNT)
        
        ;; Verify proposer is a contributor
        (asserts! (is-some (map-get? member-contributions { group-id: group-id, member: proposer })) ERR-NOT-AUTHORIZED)
        
        ;; Create proposal
        (map-set withdrawal-proposals
            { group-id: group-id, proposal-id: proposal-id }
            {
                proposer: proposer,
                amount: amount,
                recipient: recipient,
                description: description,
                created-at: stacks-block-height,
                voting-ends-at: voting-ends-at,
                votes-for: u0,
                votes-against: u0,
                total-voters: u0,
                status: "active",
                executed-at: u0
            }
        )
        
        ;; Update counter
        (map-set group-proposal-counters
            { group-id: group-id }
            {
                next-proposal-id: (+ proposal-id u1),
                total-proposals: (+ (get total-proposals counter) u1),
                executed-proposals: (get executed-proposals counter)
            }
        )
        
        (ok proposal-id)
    )
)

;; Vote on withdrawal proposal
(define-public (vote-on-proposal (group-id uint) (proposal-id uint) (vote bool))
    (let
        (
            (voter tx-sender)
            (proposal (unwrap! (map-get? withdrawal-proposals { group-id: group-id, proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (contribution (unwrap! (map-get? member-contributions { group-id: group-id, member: voter }) ERR-NOT-AUTHORIZED))
            (voting-power (get total-contributed contribution))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "active") ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (< stacks-block-height (get voting-ends-at proposal)) ERR-VOTING-CLOSED)
        (asserts! (> voting-power u0) ERR-NOT-AUTHORIZED)
        
        ;; Check if already voted
        (asserts! (is-none (map-get? proposal-votes { group-id: group-id, proposal-id: proposal-id, voter: voter })) ERR-ALREADY-VOTED)
        
        ;; Record vote
        (map-set proposal-votes
            { group-id: group-id, proposal-id: proposal-id, voter: voter }
            {
                vote: vote,
                voted-at: stacks-block-height,
                voting-power: voting-power
            }
        )
        
        ;; Update proposal vote counts
        (map-set withdrawal-proposals
            { group-id: group-id, proposal-id: proposal-id }
            (merge proposal {
                votes-for: (if vote (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
                votes-against: (if vote (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
                total-voters: (+ (get total-voters proposal) u1)
            })
        )
        
        (ok true)
    )
)

;; Execute approved withdrawal proposal
(define-public (execute-proposal (group-id uint) (proposal-id uint) (consensus-threshold uint))
    (let
        (
            (executor tx-sender)
            (proposal (unwrap! (map-get? withdrawal-proposals { group-id: group-id, proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (escrow (unwrap! (map-get? group-escrows { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (counter (unwrap! (map-get? group-proposal-counters { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
            (approval-rate (if (> total-votes u0) (* (/ (get votes-for proposal) total-votes) u100) u0))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status proposal) "active") ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (>= stacks-block-height (get voting-ends-at proposal)) ERR-VOTING-CLOSED)
        (asserts! (>= approval-rate consensus-threshold) ERR-CONSENSUS-NOT-REACHED)
        (asserts! (>= (get total-balance escrow) (get amount proposal)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Calculate platform fee
        (let
            (
                (fee-amount (/ (* (get amount proposal) (var-get platform-fee-rate)) u10000))
                (net-amount (- (get amount proposal) fee-amount))
            )
            
            ;; Transfer funds to recipient
            (try! (as-contract (stx-transfer? net-amount tx-sender (get recipient proposal))))
            
            ;; Transfer fee to contract owner (if any)
            (if (> fee-amount u0)
                (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT-OWNER)))
                true
            )
            
            ;; Update proposal status
            (map-set withdrawal-proposals
                { group-id: group-id, proposal-id: proposal-id }
                (merge proposal {
                    status: "executed",
                    executed-at: stacks-block-height
                })
            )
            
            ;; Update escrow balance
            (map-set group-escrows
                { group-id: group-id }
                (merge escrow {
                    total-balance: (- (get total-balance escrow) (get amount proposal)),
                    total-withdrawals: (+ (get total-withdrawals escrow) (get amount proposal)),
                    last-activity: stacks-block-height
                })
            )
            
            ;; Update executed proposals counter
            (map-set group-proposal-counters
                { group-id: group-id }
                (merge counter {
                    executed-proposals: (+ (get executed-proposals counter) u1)
                })
            )
            
            (ok net-amount)
        )
    )
)

;; Emergency withdrawal (higher consensus required)
(define-public (emergency-withdrawal (group-id uint) (amount uint) (recipient principal))
    (let
        (
            (caller tx-sender)
            (escrow (unwrap! (map-get? group-escrows { group-id: group-id }) ERR-GROUP-NOT-FOUND))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active escrow) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get total-balance escrow) amount) ERR-INSUFFICIENT-FUNDS)
        
        ;; This would require special consensus mechanism (simplified for demo)
        ;; In practice, would need unanimous approval or special emergency protocol
        
        (ok true)
    )
)

;; Read-only functions

;; Get group escrow information
(define-read-only (get-group-escrow (group-id uint))
    (map-get? group-escrows { group-id: group-id })
)

;; Get member contribution information
(define-read-only (get-member-contribution (group-id uint) (member principal))
    (map-get? member-contributions { group-id: group-id, member: member })
)

;; Get withdrawal proposal
(define-read-only (get-proposal (group-id uint) (proposal-id uint))
    (map-get? withdrawal-proposals { group-id: group-id, proposal-id: proposal-id })
)

;; Get vote information
(define-read-only (get-vote (group-id uint) (proposal-id uint) (voter principal))
    (map-get? proposal-votes { group-id: group-id, proposal-id: proposal-id, voter: voter })
)

;; Get proposal counters
(define-read-only (get-proposal-counters (group-id uint))
    (map-get? group-proposal-counters { group-id: group-id })
)

;; Calculate voting power for member
(define-read-only (get-voting-power (group-id uint) (member principal))
    (match (map-get? member-contributions { group-id: group-id, member: member })
        contribution (get total-contributed contribution)
        u0
    )
)

;; Check if proposal has reached consensus
(define-read-only (check-consensus (group-id uint) (proposal-id uint) (threshold uint))
    (match (map-get? withdrawal-proposals { group-id: group-id, proposal-id: proposal-id })
        proposal 
        (let
            (
                (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
                (approval-rate (if (> total-votes u0) (* (/ (get votes-for proposal) total-votes) u100) u0))
            )
            (>= approval-rate threshold)
        )
        false
    )
)

;; Get contract stats
(define-read-only (get-contract-stats)
    {
        contract-paused: (var-get contract-paused),
        minimum-contribution: (var-get minimum-contribution),
        platform-fee-rate: (var-get platform-fee-rate)
    }
)

;; Admin functions

;; Pause/unpause contract (owner only)
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused paused)
        (ok true)
    )
)

;; Update minimum contribution (owner only)
(define-public (set-minimum-contribution (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set minimum-contribution amount)
        (ok true)
    )
)

;; Update platform fee rate (owner only)
(define-public (set-platform-fee-rate (rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
        (var-set platform-fee-rate rate)
        (ok true)
    )
)
