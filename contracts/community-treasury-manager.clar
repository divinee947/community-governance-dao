;; Community Governance DAO - Treasury Manager
;; Manages community treasury funds with multi-signature security and governance integration

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-INSUFFICIENT-FUNDS (err u201))
(define-constant ERR-INVALID-AMOUNT (err u202))
(define-constant ERR-INVALID-RECIPIENT (err u203))
(define-constant ERR-PROPOSAL-NOT-APPROVED (err u204))
(define-constant ERR-ALREADY-EXECUTED (err u205))
(define-constant ERR-INVALID-SIGNATURES (err u206))
(define-constant ERR-SPENDING-LIMIT-EXCEEDED (err u207))
(define-constant ERR-INVALID-MULTISIG (err u208))
(define-constant ERR-TRANSACTION-NOT-FOUND (err u209))
(define-constant ERR-GRANT-NOT-FOUND (err u210))
(define-constant ERR-BUDGET-EXCEEDED (err u211))

;; Data Variables
(define-data-var treasury-balance uint u0)
(define-data-var transaction-counter uint u0)
(define-data-var grant-counter uint u0)
(define-data-var multisig-threshold uint u2) ;; Minimum signatures required
(define-data-var daily-spending-limit uint u10000) ;; Daily spending limit in microSTX
(define-data-var emergency-spending-limit uint u50000) ;; Emergency spending limit
(define-data-var governance-contract principal tx-sender) ;; Will be updated to governance contract

;; Transaction Status
(define-constant TX-STATUS-PENDING u0)
(define-constant TX-STATUS-APPROVED u1)
(define-constant TX-STATUS-EXECUTED u2)
(define-constant TX-STATUS-REJECTED u3)
(define-constant TX-STATUS-EXPIRED u4)

;; Grant Status
(define-constant GRANT-STATUS-ACTIVE u0)
(define-constant GRANT-STATUS-COMPLETED u1)
(define-constant GRANT-STATUS-CANCELLED u2)

;; Transaction Types
(define-constant TX-TYPE-GOVERNANCE u0)
(define-constant TX-TYPE-GRANT u1)
(define-constant TX-TYPE-OPERATIONAL u2)
(define-constant TX-TYPE-EMERGENCY u3)

;; Data Maps
(define-map TreasuryTransactions
    { tx-id: uint }
    {
        proposer: principal,
        recipient: principal,
        amount: uint,
        description: (string-ascii 200),
        tx-type: uint,
        proposal-id: (optional uint),
        created-at: uint,
        approved-at: (optional uint),
        executed-at: (optional uint),
        status: uint,
        required-signatures: uint,
        signatures-count: uint,
        expiry-block: uint
    }
)

(define-map TransactionSignatures
    { tx-id: uint, signer: principal }
    { signature-block: uint, signature-valid: bool }
)

(define-map AuthorizedSigners
    { signer: principal }
    { authorized: bool, added-at: uint, added-by: principal }
)

(define-map CommunityGrants
    { grant-id: uint }
    {
        grantee: principal,
        title: (string-ascii 100),
        description: (string-ascii 300),
        total-amount: uint,
        amount-paid: uint,
        milestone-count: uint,
        milestones-completed: uint,
        created-at: uint,
        status: uint,
        proposal-id: uint
    }
)

(define-map GrantMilestones
    { grant-id: uint, milestone-id: uint }
    {
        description: (string-ascii 200),
        amount: uint,
        due-date: uint,
        completed-at: (optional uint),
        approved-by: (optional principal),
        status: uint
    }
)

(define-map DailySpending
    { date: uint }
    { amount-spent: uint, transaction-count: uint }
)

(define-map TreasuryBudgets
    { category: (string-ascii 50) }
    { 
        allocated-amount: uint,
        spent-amount: uint,
        period-start: uint,
        period-end: uint,
        updated-by: principal
    }
)

(define-map FinancialReports
    { report-id: uint }
    {
        period-start: uint,
        period-end: uint,
        total-income: uint,
        total-expenses: uint,
        grant-expenses: uint,
        operational-expenses: uint,
        created-by: principal,
        created-at: uint
    }
)

;; Public Functions

;; Initialize treasury with authorized signers
(define-public (initialize-treasury (initial-signers (list 10 principal)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map add-authorized-signer initial-signers)
        (ok true)
    )
)

;; Add funds to treasury (accepts STX deposits)
(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        ;; Update treasury balance
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        ;; Record transaction
        (let (
            (tx-id (+ (var-get transaction-counter) u1))
        )
            (map-set TreasuryTransactions
                { tx-id: tx-id }
                {
                    proposer: tx-sender,
                    recipient: (as-contract tx-sender),
                    amount: amount,
                    description: "Treasury deposit",
                    tx-type: TX-TYPE-OPERATIONAL,
                    proposal-id: none,
                    created-at: block-height,
                    approved-at: (some block-height),
                    executed-at: (some block-height),
                    status: TX-STATUS-EXECUTED,
                    required-signatures: u0,
                    signatures-count: u0,
                    expiry-block: (+ block-height u1000)
                }
            )
            (var-set transaction-counter tx-id)
            (ok amount)
        )
    )
)

;; Request funds through governance proposal
(define-public (request-funds 
    (recipient principal)
    (amount uint)
    (description (string-ascii 200))
    (tx-type uint)
    (proposal-id (optional uint))
)
    (let (
        (tx-id (+ (var-get transaction-counter) u1))
        (required-sigs (var-get multisig-threshold))
    )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq recipient (as-contract tx-sender))) ERR-INVALID-RECIPIENT)
        
        ;; Check spending limits based on transaction type
        (asserts! (validate-spending-limits amount tx-type) ERR-SPENDING-LIMIT-EXCEEDED)
        
        (map-set TreasuryTransactions
            { tx-id: tx-id }
            {
                proposer: tx-sender,
                recipient: recipient,
                amount: amount,
                description: description,
                tx-type: tx-type,
                proposal-id: proposal-id,
                created-at: block-height,
                approved-at: none,
                executed-at: none,
                status: TX-STATUS-PENDING,
                required-signatures: required-sigs,
                signatures-count: u0,
                expiry-block: (+ block-height u1000) ;; Expires in ~7 days
            }
        )
        
        (var-set transaction-counter tx-id)
        (ok tx-id)
    )
)

;; Sign a transaction (multi-signature approval)
(define-public (sign-transaction (tx-id uint))
    (let (
        (transaction (unwrap! (map-get? TreasuryTransactions { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND))
        (signer-authorized (default-to false (get authorized (map-get? AuthorizedSigners { signer: tx-sender }))))
        (already-signed (is-some (map-get? TransactionSignatures { tx-id: tx-id, signer: tx-sender })))
    )
        (asserts! signer-authorized ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status transaction) TX-STATUS-PENDING) ERR-ALREADY-EXECUTED)
        (asserts! (< block-height (get expiry-block transaction)) ERR-ALREADY-EXECUTED)
        (asserts! (not already-signed) ERR-INVALID-SIGNATURES)
        
        ;; Record signature
        (map-set TransactionSignatures
            { tx-id: tx-id, signer: tx-sender }
            { signature-block: block-height, signature-valid: true }
        )
        
        ;; Update signature count
        (let (
            (new-sig-count (+ (get signatures-count transaction) u1))
            (updated-transaction (merge transaction { signatures-count: new-sig-count }))
        )
            (map-set TreasuryTransactions { tx-id: tx-id } updated-transaction)
            
            ;; Auto-approve if threshold met
            (if (>= new-sig-count (get required-signatures transaction))
                (begin
                    (map-set TreasuryTransactions 
                        { tx-id: tx-id } 
                        (merge updated-transaction { 
                            status: TX-STATUS-APPROVED,
                            approved-at: (some block-height)
                        })
                    )
                    (ok { approved: true, signatures: new-sig-count })
                )
                (ok { approved: false, signatures: new-sig-count })
            )
        )
    )
)

;; Execute approved transaction
(define-public (execute-transaction (tx-id uint))
    (let (
        (transaction (unwrap! (map-get? TreasuryTransactions { tx-id: tx-id }) ERR-TRANSACTION-NOT-FOUND))
    )
        (asserts! (is-eq (get status transaction) TX-STATUS-APPROVED) ERR-PROPOSAL-NOT-APPROVED)
        (asserts! (<= (get amount transaction) (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Execute the transfer
        (try! (as-contract (stx-transfer? (get amount transaction) tx-sender (get recipient transaction))))
        
        ;; Update treasury balance
        (var-set treasury-balance (- (var-get treasury-balance) (get amount transaction)))
        
        ;; Update transaction status
        (map-set TreasuryTransactions
            { tx-id: tx-id }
            (merge transaction {
                status: TX-STATUS-EXECUTED,
                executed-at: (some block-height)
            })
        )
        
        ;; Update daily spending tracking
        (update-daily-spending (get amount transaction))
        
        (ok true)
    )
)

;; Create community grant
(define-public (create-grant
    (grantee principal)
    (title (string-ascii 100))
    (description (string-ascii 300))
    (total-amount uint)
    (milestone-count uint)
    (proposal-id uint)
)
    (let (
        (grant-id (+ (var-get grant-counter) u1))
    )
        (asserts! (> total-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> milestone-count u0) ERR-INVALID-AMOUNT)
        (asserts! (<= total-amount (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
        
        (map-set CommunityGrants
            { grant-id: grant-id }
            {
                grantee: grantee,
                title: title,
                description: description,
                total-amount: total-amount,
                amount-paid: u0,
                milestone-count: milestone-count,
                milestones-completed: u0,
                created-at: block-height,
                status: GRANT-STATUS-ACTIVE,
                proposal-id: proposal-id
            }
        )
        
        (var-set grant-counter grant-id)
        (ok grant-id)
    )
)

;; Process milestone payment for grant
(define-public (process-milestone-payment (grant-id uint) (milestone-id uint))
    (let (
        (grant (unwrap! (map-get? CommunityGrants { grant-id: grant-id }) ERR-GRANT-NOT-FOUND))
        (milestone (unwrap! (map-get? GrantMilestones { grant-id: grant-id, milestone-id: milestone-id }) ERR-GRANT-NOT-FOUND))
        (signer-authorized (default-to false (get authorized (map-get? AuthorizedSigners { signer: tx-sender }))))
    )
        (asserts! signer-authorized ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status grant) GRANT-STATUS-ACTIVE) ERR-GRANT-NOT-FOUND)
        (asserts! (<= (get amount milestone) (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Execute milestone payment
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get grantee grant))))
        
        ;; Update treasury balance
        (var-set treasury-balance (- (var-get treasury-balance) (get amount milestone)))
        
        ;; Update grant progress
        (map-set CommunityGrants
            { grant-id: grant-id }
            (merge grant {
                amount-paid: (+ (get amount-paid grant) (get amount milestone)),
                milestones-completed: (+ (get milestones-completed grant) u1)
            })
        )
        
        ;; Mark milestone as completed
        (map-set GrantMilestones
            { grant-id: grant-id, milestone-id: milestone-id }
            (merge milestone {
                completed-at: (some block-height),
                approved-by: (some tx-sender),
                status: u1
            })
        )
        
        (ok true)
    )
)

;; Add authorized signer
(define-public (add-authorized-signer (signer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set AuthorizedSigners
            { signer: signer }
            { authorized: true, added-at: block-height, added-by: tx-sender }
        )
        (ok true)
    )
)

;; Remove authorized signer
(define-public (remove-authorized-signer (signer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set AuthorizedSigners
            { signer: signer }
            { authorized: false, added-at: block-height, added-by: tx-sender }
        )
        (ok true)
    )
)

;; Set budget for category
(define-public (set-budget 
    (category (string-ascii 50))
    (amount uint)
    (period-blocks uint)
)
    (let (
        (signer-authorized (default-to false (get authorized (map-get? AuthorizedSigners { signer: tx-sender }))))
    )
        (asserts! signer-authorized ERR-UNAUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (map-set TreasuryBudgets
            { category: category }
            {
                allocated-amount: amount,
                spent-amount: u0,
                period-start: block-height,
                period-end: (+ block-height period-blocks),
                updated-by: tx-sender
            }
        )
        (ok true)
    )
)

;; Generate financial report
(define-public (generate-financial-report 
    (period-start uint)
    (period-end uint)
    (total-income uint)
    (total-expenses uint)
    (grant-expenses uint)
    (operational-expenses uint)
)
    (let (
        (report-id (+ (var-get transaction-counter) u1))
        (signer-authorized (default-to false (get authorized (map-get? AuthorizedSigners { signer: tx-sender }))))
    )
        (asserts! signer-authorized ERR-UNAUTHORIZED)
        (asserts! (<= period-start period-end) ERR-INVALID-AMOUNT)
        
        (map-set FinancialReports
            { report-id: report-id }
            {
                period-start: period-start,
                period-end: period-end,
                total-income: total-income,
                total-expenses: total-expenses,
                grant-expenses: grant-expenses,
                operational-expenses: operational-expenses,
                created-by: tx-sender,
                created-at: block-height
            }
        )
        (ok report-id)
    )
)

;; Read-only functions

;; Get treasury balance
(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
    (map-get? TreasuryTransactions { tx-id: tx-id })
)

;; Get grant details
(define-read-only (get-grant (grant-id uint))
    (map-get? CommunityGrants { grant-id: grant-id })
)

;; Check if signer is authorized
(define-read-only (is-authorized-signer (signer principal))
    (default-to false (get authorized (map-get? AuthorizedSigners { signer: signer })))
)

;; Get spending history for a date
(define-read-only (get-daily-spending (date uint))
    (map-get? DailySpending { date: date })
)

;; Get budget for category
(define-read-only (get-budget (category (string-ascii 50)))
    (map-get? TreasuryBudgets { category: category })
)

;; Get financial report
(define-read-only (get-financial-report (report-id uint))
    (map-get? FinancialReports { report-id: report-id })
)

;; Get transaction signatures
(define-read-only (get-transaction-signature (tx-id uint) (signer principal))
    (map-get? TransactionSignatures { tx-id: tx-id, signer: signer })
)

;; Get transaction counter
(define-read-only (get-transaction-counter)
    (var-get transaction-counter)
)

;; Get grant counter
(define-read-only (get-grant-counter)
    (var-get grant-counter)
)

;; Private functions

;; Validate spending limits
(define-private (validate-spending-limits (amount uint) (tx-type uint))
    (let (
        (daily-limit (var-get daily-spending-limit))
        (emergency-limit-val (var-get emergency-spending-limit))
        (today-spending (default-to u0 (get amount-spent (map-get? DailySpending { date: (/ block-height u144) }))))
    )
        (if (is-eq tx-type TX-TYPE-EMERGENCY)
            (<= amount emergency-limit-val)
            (<= (+ amount today-spending) daily-limit)
        )
    )
)

;; Update daily spending tracking
(define-private (update-daily-spending (amount uint))
    (let (
        (today (/ block-height u144))
        (current-spending (default-to 
            { amount-spent: u0, transaction-count: u0 }
            (map-get? DailySpending { date: today })
        ))
    )
        (map-set DailySpending
            { date: today }
            {
                amount-spent: (+ (get amount-spent current-spending) amount),
                transaction-count: (+ (get transaction-count current-spending) u1)
            }
        )
    )
)

;; Helper function for adding signers
(define-private (add-authorized-signer-helper (signer principal))
    (map-set AuthorizedSigners
        { signer: signer }
        { authorized: true, added-at: block-height, added-by: CONTRACT-OWNER }
    )
)

;; Contract initialization
(begin
    (var-set treasury-balance u0)
    (var-set transaction-counter u0)
    (var-set grant-counter u0)
)
