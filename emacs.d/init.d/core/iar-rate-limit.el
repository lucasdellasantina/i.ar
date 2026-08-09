;; -*- lexical-binding: t; -*-

;;; Rate Limiter -- Sleep before tool execution
;;
;; Crude rate limiting for execute_code_local and execute_code_remote.
;; When IAR_RATE_LIMIT env var is set (seconds), each call sleeps for
;; that duration before executing. This prevents aggressive scanning
;; against real targets during autonomous pentesting.
;;
;; The rate limit is read once from the environment at load time and
;; stored in `iar-rate-limit-seconds'. It can also be set dynamically
;; (e.g., by a project config or interactive command).
;;
;; This is intentionally simple -- a global sleep before every call.
;; Per-target or per-command rate limiting can be added later when
;; the pentesting workflow demands it.

(require 'subr-x)

(defcustom iar-rate-limit-seconds nil
  "Seconds to sleep before execute_code_local/remote calls.
When nil, no rate limiting is applied (default).
Set via IAR_RATE_LIMIT env var or dynamically.
This is a global rate limit -- every call sleeps the same amount.
Crude but safe for autonomous pentesting against real targets."
  :type '(choice (const :tag "Disabled" nil)
                 (integer :tag "Seconds"))
  :group 'iar)

;;; --- Initialization from env var ---

(defun iar--rate-limit-init ()
  "Initialize rate limit from IAR_RATE_LIMIT env var.
Called at module load time. Does nothing if env var is not set."
  (let ((raw (getenv "IAR_RATE_LIMIT")))
    (when (and raw (not (string-empty-p raw)))
      (let ((secs (string-to-number raw)))
        (when (and (integerp secs) (> secs 0))
          (setq iar-rate-limit-seconds secs)
          (message "[rate-limit] Enabled: %ds sleep before each exec call" secs))))))

;; Initialize at load time
(iar--rate-limit-init)

;;; --- Public API ---

(defun iar--rate-limit-maybe-sleep ()
  "Sleep for `iar-rate-limit-seconds' if rate limiting is enabled.
Returns t if a sleep was performed, nil otherwise.
The sleep uses `sit-for' so Emacs stays responsive during the wait."
  (when (and (integerp iar-rate-limit-seconds)
             (> iar-rate-limit-seconds 0))
    (message "[rate-limit] Sleeping %ds before exec..." iar-rate-limit-seconds)
    (sit-for iar-rate-limit-seconds)
    t))

(defun iar-rate-limit-set (seconds)
  "Set rate limit to SECONDS.
When SECONDS is nil or 0, rate limiting is disabled."
  (interactive
   (list (read-number "Rate limit seconds (0 to disable): ")))
  (setq iar-rate-limit-seconds
        (if (and (integerp seconds) (> seconds 0))
            seconds
          nil))
  (if iar-rate-limit-seconds
      (message "[rate-limit] Set to %ds" iar-rate-limit-seconds)
    (message "[rate-limit] Disabled")))

(provide 'iar-rate-limit)