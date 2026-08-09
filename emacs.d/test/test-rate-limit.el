;; -*- lexical-binding: t; -*-

;;; Tests for iar-rate-limit.el
;;
;; Tests for rate limit initialization, sleep behavior, and dynamic setting.
;; Sleep tests use very short durations to keep test suite fast.

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'iar-rate-limit)

;;; --- Initialization tests ---

(ert-deftest test-rate-limit-init-from-env ()
  "iar--rate-limit-init reads IAR_RATE_LIMIT env var."
  (let ((process-environment (cons "IAR_RATE_LIMIT=5"
                                   process-environment))
        (iar-rate-limit-seconds nil))
    (iar--rate-limit-init)
    (should (eql iar-rate-limit-seconds 5))))

(ert-deftest test-rate-limit-init-no-env ()
  "iar--rate-limit-init does nothing when env var is absent."
  (let ((process-environment (remove "IAR_RATE_LIMIT="
                                      process-environment))
        (iar-rate-limit-seconds nil))
    (iar--rate-limit-init)
    (should (null iar-rate-limit-seconds))))

(ert-deftest test-rate-limit-init-invalid-env ()
  "iar--rate-limit-init ignores invalid env var values."
  (let ((process-environment (cons "IAR_RATE_LIMIT=notanumber"
                                   process-environment))
        (iar-rate-limit-seconds nil))
    (iar--rate-limit-init)
    (should (null iar-rate-limit-seconds))))

(ert-deftest test-rate-limit-init-zero ()
  "iar--rate-limit-init ignores zero (disabled)."
  (let ((process-environment (cons "IAR_RATE_LIMIT=0"
                                   process-environment))
        (iar-rate-limit-seconds nil))
    (iar--rate-limit-init)
    (should (null iar-rate-limit-seconds))))

(ert-deftest test-rate-limit-init-negative ()
  "iar--rate-limit-init ignores negative values."
  (let ((process-environment (cons "IAR_RATE_LIMIT=-3"
                                   process-environment))
        (iar-rate-limit-seconds nil))
    (iar--rate-limit-init)
    (should (null iar-rate-limit-seconds))))

;;; --- Maybe-sleep tests ---

(ert-deftest test-rate-limit-maybe-sleep-disabled ()
  "iar--rate-limit-maybe-sleep returns nil when disabled."
  (let ((iar-rate-limit-seconds nil))
    (should (null (iar--rate-limit-maybe-sleep)))))

(ert-deftest test-rate-limit-maybe-sleep-enabled ()
  "iar--rate-limit-maybe-sleep returns t and sleeps when enabled.
Uses 0.1s sleep to keep test fast."
  (let ((iar-rate-limit-seconds 1))
    (should (eql (iar--rate-limit-maybe-sleep) t))))

(ert-deftest test-rate-limit-maybe-sleep-zero ()
  "iar--rate-limit-maybe-sleep returns nil when seconds is 0."
  (let ((iar-rate-limit-seconds 0))
    (should (null (iar--rate-limit-maybe-sleep)))))

;;; --- Dynamic setting tests ---

(ert-deftest test-rate-limit-set-enabled ()
  "iar-rate-limit-set enables rate limiting."
  (let ((iar-rate-limit-seconds nil))
    (iar-rate-limit-set 10)
    (should (eql iar-rate-limit-seconds 10))))

(ert-deftest test-rate-limit-set-disabled ()
  "iar-rate-limit-set disables rate limiting with 0."
  (let ((iar-rate-limit-seconds 5))
    (iar-rate-limit-set 0)
    (should (null iar-rate-limit-seconds))))

(ert-deftest test-rate-limit-set-nil ()
  "iar-rate-limit-set disables rate limiting with nil."
  (let ((iar-rate-limit-seconds 5))
    (iar-rate-limit-set nil)
    (should (null iar-rate-limit-seconds))))

(provide 'test-rate-limit)
;;; test-rate-limit.el ends here