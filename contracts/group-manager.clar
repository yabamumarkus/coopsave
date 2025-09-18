;; Coopsave Group Manager Contract
;; Manages group creation, membership, and configuration for cooperative savings
;; Handles group settings, member roles, and consensus thresholds

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GROUP-EXISTS (err u101))
(define-constant ERR-GROUP-NOT-FOUND (err u102))
(define-constant ERR-MEMBER-EXISTS (err u103))
(define-constant ERR-MEMBER-NOT-FOUND (err u104))
(define-constant ERR-INVALID-THRESHOLD (err u105))
(define-constant ERR-GROUP-FULL (err u106))
(define-constant ERR-INVALID-PARAMETER (err u107))
(define-constant ERR-INSUFFICIENT-MEMBERS (err u108))

;; Data structures
(define-map groups
    { group-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        creator: principal,
        created-at: uint,
        member-count: uint,
        max-members: uint,
        consensus-threshold: uint,
        voting-period: uint,
        is-active: bool,
        total-contributions: uint
    }
)

(define-map group-members
    { group-id: uint, member: principal }
    {
        joined-at: uint,
        role: (string-ascii 20),
        is-active: bool,
        total-contributed: uint,
        reputation-score: uint
    }
)

(define-map member-groups
    { member: principal }
    {
        group-ids: (list 10 uint),
        active-groups: uint
    }
)

(define-map group-invitations
    { group-id: uint, invitee: principal }
    {
        invited-by: principal,
        invited-at: uint,
        status: (string-ascii 20),
        expires-at: uint
    }
)

;; Data variables
(define-data-var next-group-id uint u1)
(define-data-var total-groups uint u0)
(define-data-var contract-paused bool false)

;; Public functions

;; Create a new savings group
(define-public (create-group
    (name (string-ascii 50))
    (description (string-ascii 200))
    (max-members uint)
    (consensus-threshold uint)
    (voting-period uint)
)
    (let
        (
            (group-id (var-get next-group-id))
            (creator tx-sender)
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMETER)
        (asserts! (and (>= max-members u2) (<= max-members u20)) ERR-INVALID-PARAMETER)
        (asserts! (and (>= consensus-threshold u50) (<= consensus-threshold u100)) ERR-INVALID-THRESHOLD)
        (asserts! (and (>= voting-period u144) (<= voting-period u1008)) ERR-INVALID-PARAMETER) ;; 1-7 days in blocks
        
        ;; Create group
        (map-set groups
            { group-id: group-id }
            {
                name: name,
                description: description,
                creator: creator,
                created-at: stacks-block-height,
                member-count: u1,
                max-members: max-members,
                consensus-threshold: consensus-threshold,
                voting-period: voting-period,
                is-active: true,
                total-contributions: u0
            }
        )
        
        ;; Add creator as first member with admin role
        (map-set group-members
            { group-id: group-id, member: creator }
            {
                joined-at: stacks-block-height,
                role: "admin",
                is-active: true,
                total-contributed: u0,
                reputation-score: u100
            }
        )
        
        ;; Update creator's member groups
        (let
            (
                (member-data (default-to { group-ids: (list), active-groups: u0 }
                    (map-get? member-groups { member: creator })))
            )
            (map-set member-groups
                { member: creator }
                {
                    group-ids: (unwrap! (as-max-len? (append (get group-ids member-data) group-id) u10) ERR-INVALID-PARAMETER),
                    active-groups: (+ (get active-groups member-data) u1)
                }
            )
        )
        
        ;; Update counters
        (var-set next-group-id (+ group-id u1))
        (var-set total-groups (+ (var-get total-groups) u1))
        
        (ok group-id)
    )
)

;; Invite a member to join a group
(define-public (invite-member (group-id uint) (invitee principal))
    (let
        (
            (group (unwrap! (map-get? groups { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (inviter tx-sender)
            (expires-at (+ stacks-block-height u1008)) ;; 7 days
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active group) ERR-NOT-AUTHORIZED)
        (asserts! (< (get member-count group) (get max-members group)) ERR-GROUP-FULL)
        
        ;; Check if inviter is a member with permission
        (asserts! (is-some (map-get? group-members { group-id: group-id, member: inviter })) ERR-NOT-AUTHORIZED)
        
        ;; Check if invitee is not already a member
        (asserts! (is-none (map-get? group-members { group-id: group-id, member: invitee })) ERR-MEMBER-EXISTS)
        
        ;; Create invitation
        (map-set group-invitations
            { group-id: group-id, invitee: invitee }
            {
                invited-by: inviter,
                invited-at: stacks-block-height,
                status: "pending",
                expires-at: expires-at
            }
        )
        
        (ok true)
    )
)

;; Accept an invitation to join a group
(define-public (accept-invitation (group-id uint))
    (let
        (
            (invitee tx-sender)
            (invitation (unwrap! (map-get? group-invitations { group-id: group-id, invitee: invitee }) ERR-MEMBER-NOT-FOUND))
            (group (unwrap! (map-get? groups { group-id: group-id }) ERR-GROUP-NOT-FOUND))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status invitation) "pending") ERR-NOT-AUTHORIZED)
        (asserts! (< stacks-block-height (get expires-at invitation)) ERR-NOT-AUTHORIZED)
        (asserts! (< (get member-count group) (get max-members group)) ERR-GROUP-FULL)
        
        ;; Add member to group
        (map-set group-members
            { group-id: group-id, member: invitee }
            {
                joined-at: stacks-block-height,
                role: "member",
                is-active: true,
                total-contributed: u0,
                reputation-score: u50
            }
        )
        
        ;; Update invitation status
        (map-set group-invitations
            { group-id: group-id, invitee: invitee }
            (merge invitation { status: "accepted" })
        )
        
        ;; Update group member count
        (map-set groups
            { group-id: group-id }
            (merge group { member-count: (+ (get member-count group) u1) })
        )
        
        ;; Update member's group list
        (let
            (
                (member-data (default-to { group-ids: (list), active-groups: u0 }
                    (map-get? member-groups { member: invitee })))
            )
            (map-set member-groups
                { member: invitee }
                {
                    group-ids: (unwrap! (as-max-len? (append (get group-ids member-data) group-id) u10) ERR-INVALID-PARAMETER),
                    active-groups: (+ (get active-groups member-data) u1)
                }
            )
        )
        
        (ok true)
    )
)

;; Leave a group (members can leave, but creator cannot leave if group has funds)
(define-public (leave-group (group-id uint))
    (let
        (
            (member tx-sender)
            (group (unwrap! (map-get? groups { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (member-data (unwrap! (map-get? group-members { group-id: group-id, member: member }) ERR-MEMBER-NOT-FOUND))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active member-data) ERR-NOT-AUTHORIZED)
        
        ;; Creator cannot leave if group has contributions (safety check)
        (if (is-eq member (get creator group))
            (asserts! (is-eq (get total-contributions group) u0) ERR-NOT-AUTHORIZED)
            true
        )
        
        ;; Deactivate member
        (map-set group-members
            { group-id: group-id, member: member }
            (merge member-data { is-active: false })
        )
        
        ;; Update group member count
        (map-set groups
            { group-id: group-id }
            (merge group { member-count: (- (get member-count group) u1) })
        )
        
        ;; Deactivate group if no active members remain
        (if (is-eq (- (get member-count group) u1) u0)
            (map-set groups
                { group-id: group-id }
                (merge group { is-active: false })
            )
            true
        )
        
        (ok true)
    )
)

;; Update group settings (admin only)
(define-public (update-group-settings 
    (group-id uint) 
    (new-consensus-threshold uint) 
    (new-voting-period uint)
)
    (let
        (
            (admin tx-sender)
            (group (unwrap! (map-get? groups { group-id: group-id }) ERR-GROUP-NOT-FOUND))
            (member-data (unwrap! (map-get? group-members { group-id: group-id, member: admin }) ERR-MEMBER-NOT-FOUND))
        )
        (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get role member-data) "admin") ERR-NOT-AUTHORIZED)
        (asserts! (and (>= new-consensus-threshold u50) (<= new-consensus-threshold u100)) ERR-INVALID-THRESHOLD)
        (asserts! (and (>= new-voting-period u144) (<= new-voting-period u1008)) ERR-INVALID-PARAMETER)
        
        (map-set groups
            { group-id: group-id }
            (merge group {
                consensus-threshold: new-consensus-threshold,
                voting-period: new-voting-period
            })
        )
        
        (ok true)
    )
)

;; Read-only functions

;; Get group information
(define-read-only (get-group (group-id uint))
    (map-get? groups { group-id: group-id })
)

;; Get member information
(define-read-only (get-member (group-id uint) (member principal))
    (map-get? group-members { group-id: group-id, member: member })
)

;; Get member's groups
(define-read-only (get-member-groups (member principal))
    (map-get? member-groups { member: member })
)

;; Get invitation status
(define-read-only (get-invitation (group-id uint) (invitee principal))
    (map-get? group-invitations { group-id: group-id, invitee: invitee })
)

;; Check if user is member of group
(define-read-only (is-group-member (group-id uint) (member principal))
    (match (map-get? group-members { group-id: group-id, member: member })
        member-data (get is-active member-data)
        false
    )
)

;; Check if user is admin of group
(define-read-only (is-group-admin (group-id uint) (member principal))
    (match (map-get? group-members { group-id: group-id, member: member })
        member-data (and (get is-active member-data) (is-eq (get role member-data) "admin"))
        false
    )
)

;; Get contract stats
(define-read-only (get-contract-stats)
    {
        total-groups: (var-get total-groups),
        next-group-id: (var-get next-group-id),
        contract-paused: (var-get contract-paused)
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
