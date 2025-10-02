;; title: journalist-verification-network
;; version: 1.0.0
;; summary: Secure channels for verified journalist access to submissions
;; description: Journalist identity verification system with secure access control,
;;              reputation tracking, and audit logging for document access

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_JOURNALIST_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_VERIFIED (err u202))
(define-constant ERR_VERIFICATION_FAILED (err u203))
(define-constant ERR_ACCESS_DENIED (err u204))
(define-constant ERR_INVALID_CREDENTIALS (err u205))
(define-constant ERR_SUBMISSION_ACCESS_DENIED (err u206))
(define-constant ERR_REPUTATION_TOO_LOW (err u207))
(define-constant ERR_MULTI_SIG_REQUIRED (err u208))
(define-constant ERR_INSUFFICIENT_ENDORSEMENTS (err u209))

(define-constant MIN_REPUTATION_SCORE u50)
(define-constant VERIFICATION_PERIOD_BLOCKS u52560) ;; ~1 year
(define-constant MAX_ACCESS_ATTEMPTS_PER_DAY u100)
(define-constant MULTI_SIG_THRESHOLD u3)
(define-constant MIN_ENDORSEMENTS_REQUIRED u2)
(define-constant REPUTATION_DECAY_RATE u5)

;; data vars
(define-data-var journalist-counter uint u0)
(define-data-var verification-authority principal CONTRACT_OWNER)
(define-data-var network-active bool true)
(define-data-var total-journalists uint u0)
(define-data-var total-access-logs uint u0)
(define-data-var multi-sig-enabled bool true)
(define-data-var endorsement-system-active bool true)

;; data maps
(define-map journalists
  principal
  {
    journalist-id: uint,
    verification-status: (string-ascii 32),
    verification-date: uint,
    expiry-date: uint,
    reputation-score: uint,
    organization: (string-ascii 128),
    credentials-hash: (buff 64),
    access-count: uint,
    last-access: uint,
    endorsement-count: uint,
    blocked: bool,
    multi-sig-keys: (list 5 (buff 33))
  }
)

(define-map journalist-lookup
  uint  ;; journalist-id
  principal  ;; journalist-address
)

(define-map access-logs
  uint
  {
    journalist-id: uint,
    submission-id: uint,
    access-time: uint,
    access-type: (string-ascii 32),
    ip-hash: (buff 32),
    success: bool,
    multi-sig-verified: bool
  }
)

(define-map endorsements
  { endorser: principal, endorsed: principal }
  {
    endorsement-time: uint,
    endorsement-type: (string-ascii 32),
    weight: uint,
    active: bool
  }
)

(define-map organization-registry
  (string-ascii 128)  ;; organization-name
  {
    verified: bool,
    registration-date: uint,
    journalist-count: uint,
    reputation-score: uint
  }
)

(define-map multi-sig-transactions
  uint  ;; transaction-id
  {
    journalist-id: uint,
    submission-id: uint,
    signatures: (list 5 (buff 65)),
    required-signatures: uint,
    completed: bool,
    created-at: uint
  }
)

(define-map reputation-history
  { journalist: principal, block-height: uint }
  uint  ;; reputation-score
)

;; public functions

;; Register a new journalist for verification
(define-public (register-journalist
  (journalist-address principal)
  (organization (string-ascii 128))
  (credentials-hash (buff 64))
  (initial-multi-sig-keys (list 5 (buff 33)))
  )
  (let (
    (journalist-id (+ (var-get journalist-counter) u1))
    (current-block burn-block-height)
  )
    (asserts! (var-get network-active) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? journalists journalist-address)) ERR_ALREADY_VERIFIED)
    (asserts! (> (len organization) u0) ERR_INVALID_CREDENTIALS)
    (asserts! (> (len credentials-hash) u0) ERR_INVALID_CREDENTIALS)
    
    ;; Register organization if new
    (unwrap! (register-organization organization) ERR_INVALID_CREDENTIALS)
    
    ;; Create journalist record
    (map-set journalists journalist-address {
      journalist-id: journalist-id,
      verification-status: "pending",
      verification-date: current-block,
      expiry-date: (+ current-block VERIFICATION_PERIOD_BLOCKS),
      reputation-score: u0,
      organization: organization,
      credentials-hash: credentials-hash,
      access-count: u0,
      last-access: u0,
      endorsement-count: u0,
      blocked: false,
      multi-sig-keys: initial-multi-sig-keys
    })
    
    ;; Create reverse lookup
    (map-set journalist-lookup journalist-id journalist-address)
    
    ;; Update counters
    (var-set journalist-counter journalist-id)
    (var-set total-journalists (+ (var-get total-journalists) u1))
    
    (ok journalist-id)
  )
)

;; Verify a journalist (admin function)
(define-public (verify-journalist
  (journalist-address principal)
  (initial-reputation uint)
  )
  (let (
    (journalist-data (unwrap! (map-get? journalists journalist-address) ERR_JOURNALIST_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get verification-authority)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status journalist-data) "pending") ERR_ALREADY_VERIFIED)
    
    ;; Update journalist status
    (map-set journalists journalist-address
      (merge journalist-data {
        verification-status: "verified",
        reputation-score: initial-reputation
      })
    )
    
    ;; Record reputation history
    (map-set reputation-history 
      { journalist: journalist-address, block-height: burn-block-height }
      initial-reputation
    )
    
    (ok true)
  )
)

;; Request access to a submission
(define-public (request-submission-access
  (submission-id uint)
  (access-type (string-ascii 32))
  (ip-hash (buff 32))
  )
  (let (
    (journalist-data (unwrap! (map-get? journalists tx-sender) ERR_JOURNALIST_NOT_FOUND))
    (access-log-id (+ (var-get total-access-logs) u1))
  )
    (asserts! (var-get network-active) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status journalist-data) "verified") ERR_ACCESS_DENIED)
    (asserts! (not (get blocked journalist-data)) ERR_ACCESS_DENIED)
    (asserts! (>= (get reputation-score journalist-data) MIN_REPUTATION_SCORE) ERR_REPUTATION_TOO_LOW)
    (asserts! (< (get expiry-date journalist-data) burn-block-height) ERR_VERIFICATION_FAILED)
    
    ;; Check if multi-sig is required
    (if (var-get multi-sig-enabled)
      (begin 
        (unwrap! (initiate-multi-sig-access submission-id (get journalist-id journalist-data)) ERR_MULTI_SIG_REQUIRED)
        true
      )
      true
    )
    
    ;; Log access attempt
    (map-set access-logs access-log-id {
      journalist-id: (get journalist-id journalist-data),
      submission-id: submission-id,
      access-time: burn-block-height,
      access-type: access-type,
      ip-hash: ip-hash,
      success: true,
      multi-sig-verified: (var-get multi-sig-enabled)
    })
    
    ;; Update journalist access count
    (map-set journalists tx-sender
      (merge journalist-data {
        access-count: (+ (get access-count journalist-data) u1),
        last-access: burn-block-height
      })
    )
    
    ;; Update total access logs counter
    (var-set total-access-logs access-log-id)
    
    (ok access-log-id)
  )
)

;; Endorse another journalist
(define-public (endorse-journalist
  (endorsed-journalist principal)
  (endorsement-type (string-ascii 32))
  (weight uint)
  )
  (let (
    (endorser-data (unwrap! (map-get? journalists tx-sender) ERR_JOURNALIST_NOT_FOUND))
    (endorsed-data (unwrap! (map-get? journalists endorsed-journalist) ERR_JOURNALIST_NOT_FOUND))
  )
    (asserts! (var-get endorsement-system-active) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status endorser-data) "verified") ERR_ACCESS_DENIED)
    (asserts! (is-eq (get verification-status endorsed-data) "verified") ERR_ACCESS_DENIED)
    (asserts! (not (is-eq tx-sender endorsed-journalist)) ERR_UNAUTHORIZED)
    (asserts! (>= (get reputation-score endorser-data) MIN_REPUTATION_SCORE) ERR_REPUTATION_TOO_LOW)
    
    ;; Create endorsement
    (map-set endorsements 
      { endorser: tx-sender, endorsed: endorsed-journalist }
      {
        endorsement-time: burn-block-height,
        endorsement-type: endorsement-type,
        weight: weight,
        active: true
      }
    )
    
    ;; Update endorsed journalist's endorsement count
    (map-set journalists endorsed-journalist
      (merge endorsed-data {
        endorsement-count: (+ (get endorsement-count endorsed-data) u1)
      })
    )
    
    (ok true)
  )
)

;; Update journalist reputation
(define-public (update-reputation
  (journalist-address principal)
  (new-reputation uint)
  (reason (string-ascii 64))
  )
  (let (
    (journalist-data (unwrap! (map-get? journalists journalist-address) ERR_JOURNALIST_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get verification-authority)) ERR_UNAUTHORIZED)
    
    ;; Update reputation
    (map-set journalists journalist-address
      (merge journalist-data { reputation-score: new-reputation })
    )
    
    ;; Record in reputation history
    (map-set reputation-history
      { journalist: journalist-address, block-height: burn-block-height }
      new-reputation
    )
    
    (ok true)
  )
)

;; Block/unblock a journalist
(define-public (toggle-journalist-block (journalist-address principal))
  (let (
    (journalist-data (unwrap! (map-get? journalists journalist-address) ERR_JOURNALIST_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get verification-authority)) ERR_UNAUTHORIZED)
    
    (map-set journalists journalist-address
      (merge journalist-data {
        blocked: (not (get blocked journalist-data))
      })
    )
    (ok (not (get blocked journalist-data)))
  )
)

;; read only functions

;; Get journalist information
(define-read-only (get-journalist-info (journalist-address principal))
  (map-get? journalists journalist-address)
)

;; Get journalist by ID
(define-read-only (get-journalist-by-id (journalist-id uint))
  (match (map-get? journalist-lookup journalist-id)
    journalist-address (map-get? journalists journalist-address)
    none
  )
)

;; Get access log by ID
(define-read-only (get-access-log (log-id uint))
  (map-get? access-logs log-id)
)

;; Check if journalist can access submission
(define-read-only (can-access-submission (journalist-address principal) (submission-id uint))
  (match (map-get? journalists journalist-address)
    journalist-data (
      and
        (is-eq (get verification-status journalist-data) "verified")
        (not (get blocked journalist-data))
        (>= (get reputation-score journalist-data) MIN_REPUTATION_SCORE)
        (< burn-block-height (get expiry-date journalist-data))
        (if (var-get endorsement-system-active)
          (>= (get endorsement-count journalist-data) MIN_ENDORSEMENTS_REQUIRED)
          true
        )
    )
    false
  )
)

;; Get endorsement information
(define-read-only (get-endorsement (endorser principal) (endorsed principal))
  (map-get? endorsements { endorser: endorser, endorsed: endorsed })
)

;; Get organization information
(define-read-only (get-organization-info (organization (string-ascii 128)))
  (map-get? organization-registry organization)
)

;; Get total statistics
(define-read-only (get-network-statistics)
  {
    total-journalists: (var-get total-journalists),
    total-access-logs: (var-get total-access-logs),
    network-active: (var-get network-active),
    multi-sig-enabled: (var-get multi-sig-enabled),
    endorsement-system-active: (var-get endorsement-system-active)
  }
)

;; Get reputation history
(define-read-only (get-reputation-history (journalist-address principal) (block-height-ref uint))
  (map-get? reputation-history { journalist: journalist-address, block-height: block-height-ref })
)

;; private functions

;; Register organization in registry
(define-private (register-organization (organization (string-ascii 128)))
  (let (
    (org-data (default-to
      { verified: false, registration-date: u0, journalist-count: u0, reputation-score: u0 }
      (map-get? organization-registry organization)
    ))
  )
    (map-set organization-registry organization
      (merge org-data {
        journalist-count: (+ (get journalist-count org-data) u1)
      })
    )
    (ok true)
  )
)

;; Initiate multi-signature access
(define-private (initiate-multi-sig-access (submission-id uint) (journalist-id uint))
  (let (
    (transaction-id (+ (var-get total-access-logs) u1000)) ;; Offset to avoid conflicts
  )
    (map-set multi-sig-transactions transaction-id {
      journalist-id: journalist-id,
      submission-id: submission-id,
      signatures: (list ),
      required-signatures: MULTI_SIG_THRESHOLD,
      completed: false,
      created-at: burn-block-height
    })
    (ok transaction-id)
  )
)

;; Calculate journalist reputation score
(define-private (calculate-reputation-score (journalist-address principal))
  (match (map-get? journalists journalist-address)
    journalist-data {
      base-score: (get reputation-score journalist-data),
      endorsement-bonus: (* (get endorsement-count journalist-data) u10),
      access-penalty: (/ (get access-count journalist-data) u10)
    }
    { base-score: u0, endorsement-bonus: u0, access-penalty: u0 }
  )
)

;; Validate multi-signature transaction
(define-private (validate-multi-sig (transaction-id uint) (signatures (list 5 (buff 65))))
  (match (map-get? multi-sig-transactions transaction-id)
    transaction-data (>= (len signatures) (get required-signatures transaction-data))
    false
  )
)
