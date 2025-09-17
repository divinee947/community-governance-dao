;; Community Governance DAO - Voting System
;; Manages proposal submission, voting, delegation, and execution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-PROPOSAL-EXPIRED (err u102))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u103))
(define-constant ERR-ALREADY-VOTED (err u104))
(define-constant ERR-INSUFFICIENT-STAKE (err u105))
(define-constant ERR-INVALID-PROPOSAL (err u106))
(define-constant ERR-PROPOSAL-ALREADY-EXECUTED (err u107))
(define-constant ERR-VOTING-PERIOD-ENDED (err u108))
(define-constant ERR-INVALID-DELEGATION (err u109))
(define-constant ERR-EXECUTION-FAILED (err u110))

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var minimum-stake-required uint u1000)
(define-data-var voting-period-blocks uint u144) ;; ~24 hours
(define-data-var execution-delay-blocks uint u720) ;; ~5 days
(define-data-var quorum-threshold uint u30) ;; 30% participation required

;; Proposal Status Enum
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-PASSED u2)
(define-constant STATUS-REJECTED u3)
(define-constant STATUS-EXECUTED u4)
(define-constant STATUS-EXPIRED u5)

;; Vote Types
(define-constant VOTE-YES u1)
(define-constant VOTE-NO u2)
(define-constant VOTE-ABSTAIN u3)

;; Data Maps
(define-map Proposals
    { proposal-id: uint }
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        vote-start: uint,
        vote-end: uint,
        yes-votes: uint,
        no-votes: uint,
        abstain-votes: uint,
        total-votes: uint,
        status: uint,
        execution-block: uint,
        proposal-type: (string-ascii 50),
        target-contract: (optional principal),
        function-name: (optional (string-ascii 50)),
        function-args: (optional (list 10 (buff 32)))
    }
)

(define-map MemberStakes
    { member: principal }
    { stake-amount: uint, last-updated: uint }
)

(define-map VotingRecords
    { proposal-id: uint, voter: principal }
    { vote: uint, voting-power: uint, timestamp: uint }
)

(define-map VotingDelegations
    { delegator: principal }
    { delegate: principal, delegation-block: uint }
)

(define-map ProposalVoters
    { proposal-id: uint }
    { voters: (list 1000 principal) }
)

(define-map MemberParticipation
    { member: principal }
    { proposals-voted: uint, total-voting-power: uint, last-activity: uint }
)

;; Governance Parameters Map
(define-map GovernanceParams
    { param-name: (string-ascii 50) }
    { param-value: uint, last-updated: uint, updated-by: principal }
)

;; Public Functions

;; Initialize governance parameters
(define-public (initialize-governance)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set GovernanceParams 
            { param-name: "minimum-stake" } 
            { param-value: u1000, last-updated: block-height, updated-by: tx-sender })
        (map-set GovernanceParams 
            { param-name: "voting-period" } 
            { param-value: u144, last-updated: block-height, updated-by: tx-sender })
        (map-set GovernanceParams 
            { param-name: "quorum-threshold" } 
            { param-value: u30, last-updated: block-height, updated-by: tx-sender })
        (ok true)
    )
)

;; Register member stake for voting power
(define-public (register-stake (amount uint))
    (let (
        (current-stake (default-to u0 (get stake-amount (map-get? MemberStakes { member: tx-sender }))))
    )
        (asserts! (> amount u0) ERR-INVALID-PROPOSAL)
        (map-set MemberStakes 
            { member: tx-sender }
            { 
                stake-amount: (+ current-stake amount),
                last-updated: block-height 
            })
        (ok amount)
    )
)

;; Submit a new governance proposal
(define-public (submit-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (proposal-type (string-ascii 50))
    (target-contract (optional principal))
    (function-name (optional (string-ascii 50)))
    (function-args (optional (list 10 (buff 32))))
)
    (let (
        (proposal-id (+ (var-get proposal-counter) u1))
        (member-stake (get-member-stake tx-sender))
        (vote-start (+ block-height u10)) ;; 10 blocks delay before voting starts
        (vote-end (+ vote-start (var-get voting-period-blocks)))
    )
        (asserts! (>= member-stake (var-get minimum-stake-required)) ERR-INSUFFICIENT-STAKE)
        (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
        
        (map-set Proposals
            { proposal-id: proposal-id }
            {
                proposer: tx-sender,
                title: title,
                description: description,
                vote-start: vote-start,
                vote-end: vote-end,
                yes-votes: u0,
                no-votes: u0,
                abstain-votes: u0,
                total-votes: u0,
                status: STATUS-PENDING,
                execution-block: (+ vote-end (var-get execution-delay-blocks)),
                proposal-type: proposal-type,
                target-contract: target-contract,
                function-name: function-name,
                function-args: function-args
            }
        )
        
        (var-set proposal-counter proposal-id)
        (map-set ProposalVoters { proposal-id: proposal-id } { voters: (list) })
        
        (ok proposal-id)
    )
)

;; Cast a vote on a proposal
(define-public (cast-vote (proposal-id uint) (vote uint))
    (let (
        (proposal (unwrap! (map-get? Proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
        (voting-power (get-effective-voting-power tx-sender))
        (current-block block-height)
    )
        (asserts! (<= (get vote-start proposal) current-block) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (>= (get vote-end proposal) current-block) ERR-VOTING-PERIOD-ENDED)
        (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (is-none (map-get? VotingRecords { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
        (asserts! (or (is-eq vote VOTE-YES) (is-eq vote VOTE-NO) (is-eq vote VOTE-ABSTAIN)) ERR-INVALID-PROPOSAL)
        (asserts! (> voting-power u0) ERR-INSUFFICIENT-STAKE)
        
        ;; Record the vote
        (map-set VotingRecords
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: vote, voting-power: voting-power, timestamp: current-block }
        )
        
        ;; Update proposal vote counts
        (let (
            (updated-proposal (merge proposal {
                yes-votes: (if (is-eq vote VOTE-YES) (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)),
                no-votes: (if (is-eq vote VOTE-NO) (+ (get no-votes proposal) voting-power) (get no-votes proposal)),
                abstain-votes: (if (is-eq vote VOTE-ABSTAIN) (+ (get abstain-votes proposal) voting-power) (get abstain-votes proposal)),
                total-votes: (+ (get total-votes proposal) voting-power)
            }))
        )
            (map-set Proposals { proposal-id: proposal-id } updated-proposal)
        )
        
        ;; Update member participation
        (update-member-participation tx-sender voting-power)
        
        ;; Add voter to proposal voters list
        (let (
            (current-voters (default-to (list) (get voters (map-get? ProposalVoters { proposal-id: proposal-id }))))
        )
            (map-set ProposalVoters 
                { proposal-id: proposal-id } 
                { voters: (unwrap! (as-max-len? (append current-voters tx-sender) u1000) ERR-INVALID-PROPOSAL) }
            )
        )
        
        (ok true)
    )
)

;; Delegate voting power to another member
(define-public (delegate-voting-power (delegate principal))
    (let (
        (delegator-stake (get-member-stake tx-sender))
        (delegate-stake (get-member-stake delegate))
    )
        (asserts! (not (is-eq tx-sender delegate)) ERR-INVALID-DELEGATION)
        (asserts! (> delegator-stake u0) ERR-INSUFFICIENT-STAKE)
        (asserts! (> delegate-stake u0) ERR-INSUFFICIENT-STAKE)
        
        (map-set VotingDelegations
            { delegator: tx-sender }
            { delegate: delegate, delegation-block: block-height }
        )
        
        (ok true)
    )
)

;; Remove voting delegation
(define-public (remove-delegation)
    (begin
        (map-delete VotingDelegations { delegator: tx-sender })
        (ok true)
    )
)

;; Update proposal status based on voting results
(define-public (update-proposal-status (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? Proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
        (total-stake (get-total-community-stake))
        (quorum-met (>= (get total-votes proposal) (/ (* total-stake (var-get quorum-threshold)) u100)))
        (vote-passed (> (get yes-votes proposal) (get no-votes proposal)))
        (voting-ended (>= block-height (get vote-end proposal)))
    )
        (asserts! voting-ended ERR-VOTING-PERIOD-ENDED)
        (asserts! (is-eq (get status proposal) STATUS-ACTIVE) ERR-PROPOSAL-NOT-ACTIVE)
        
        (let (
            (new-status (if (and quorum-met vote-passed) STATUS-PASSED STATUS-REJECTED))
        )
            (map-set Proposals 
                { proposal-id: proposal-id }
                (merge proposal { status: new-status })
            )
            (ok new-status)
        )
    )
)

;; Execute an approved proposal
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? Proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
        (asserts! (is-eq (get status proposal) STATUS-PASSED) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (>= block-height (get execution-block proposal)) ERR-EXECUTION-FAILED)
        (asserts! (not (is-eq (get status proposal) STATUS-EXECUTED)) ERR-PROPOSAL-ALREADY-EXECUTED)
        
        ;; Mark proposal as executed
        (map-set Proposals 
            { proposal-id: proposal-id }
            (merge proposal { status: STATUS-EXECUTED })
        )
        
        ;; Here you would implement actual execution logic based on proposal type
        ;; For now, we just mark it as executed
        (ok true)
    )
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? Proposals { proposal-id: proposal-id })
)

;; Get member stake amount
(define-read-only (get-member-stake (member principal))
    (default-to u0 (get stake-amount (map-get? MemberStakes { member: member })))
)

;; Get voting record for a member on a specific proposal
(define-read-only (get-voting-record (proposal-id uint) (voter principal))
    (map-get? VotingRecords { proposal-id: proposal-id, voter: voter })
)

;; Get effective voting power (including delegations)
(define-read-only (get-effective-voting-power (member principal))
    (let (
        (base-power (get-member-stake member))
        (delegation (map-get? VotingDelegations { delegator: member }))
    )
        (if (is-some delegation)
            u0 ;; If delegated, personal voting power is 0
            (+ base-power (get-delegated-power member))
        )
    )
)

;; Get power delegated to a member
(define-read-only (get-delegated-power (delegate principal))
    ;; This is simplified - in a full implementation, you'd iterate through all delegations
    u0
)

;; Get total community stake
(define-read-only (get-total-community-stake)
    ;; This is simplified - in a full implementation, you'd sum all stakes
    u10000
)

;; Get current proposal counter
(define-read-only (get-proposal-counter)
    (var-get proposal-counter)
)

;; Get member participation stats
(define-read-only (get-member-participation (member principal))
    (map-get? MemberParticipation { member: member })
)

;; Get governance parameter
(define-read-only (get-governance-param (param-name (string-ascii 50)))
    (map-get? GovernanceParams { param-name: param-name })
)

;; Private functions

;; Update member participation statistics
(define-private (update-member-participation (member principal) (voting-power uint))
    (let (
        (current-participation (default-to 
            { proposals-voted: u0, total-voting-power: u0, last-activity: u0 }
            (map-get? MemberParticipation { member: member })
        ))
    )
        (map-set MemberParticipation
            { member: member }
            {
                proposals-voted: (+ (get proposals-voted current-participation) u1),
                total-voting-power: (+ (get total-voting-power current-participation) voting-power),
                last-activity: block-height
            }
        )
    )
)

;; Contract initialization
(begin
    (var-set proposal-counter u0)
)
