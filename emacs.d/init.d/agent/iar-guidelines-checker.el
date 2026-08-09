;; -*- lexical-binding: t; -*-

;;; Guidelines Checker
;;
;; Checks the i.ar codebase against GUIDELINES.org rules.
;; Designed to be called by the gardener agent during its monitoring cycle.
;;
;; Usage (batch mode):
;;   emacs --batch -l /root/.emacs.d/init.el \
;;         --eval '(iar-check-guidelines)' 2>&1
;;
;; Output: prints violations to stdout, one per line.
;; Returns t if violations found, nil otherwise.
;;
;; Rules checked:
;;   I.  Naming: no my-gptel--, no iar--mygptel-- prefixes
;;   II. Structure: provide statement present, provide name matches file
;;   IV. Security: no hardcoded personal data in non-test files
;;   IX. Anti-patterns: no anonymous lambdas in advice-add, no :override,
;;       no cl-return-from without cl-block, no side effects in let* bindings

(require 'cl-lib)
(require 'subr-x)

(defvar iar--guidelines-violations nil
  "List of violations found during the last guidelines check.
Each entry is a string: file:line: rule description.")

(defun iar--codebase-dir ()
  "Return the root directory of the i.ar codebase init.d/."
  (expand-file-name "init.d" user-emacs-directory))

(defun iar--all-elisp-files ()
  "Return list of all .el files in init.d/ excluding dynamic/, test/, and self."
  (let ((init-dir (iar--codebase-dir))
        (self-file (expand-file-name "iar-guidelines-checker.el"
                                      (expand-file-name "agent"
                                                        (expand-file-name "init.d" user-emacs-directory)))))
    (if (file-directory-p init-dir)
        (cl-remove-if
         (lambda (f)
           (or (string-match-p "/dynamic/" f)
               (string-match-p "/test/" f)
               (string= (expand-file-name f) self-file)))
         (directory-files-recursively init-dir "\\.el\\'"))
      nil)))

(defun iar--line-is-comment-p (line)
  "Return t if LINE is a comment line (starts with ; after optional whitespace)."
  (string-match-p "^\\s-*;" line))

(defun iar--check-line-pattern (file check-fn rule-desc)
  "Check each non-comment line of FILE with CHECK-FN.
CHECK-FN receives the line string. If it returns non-nil,
a violation with RULE-DESC is recorded."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((line-num 0))
      (while (not (eobp))
        (cl-incf line-num)
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
          (unless (iar--line-is-comment-p line)
            (when (funcall check-fn line)
              (push (format "%s:%d: %s" file line-num rule-desc)
                    iar--guidelines-violations))))
        (forward-line 1)))))

(defun iar--check-naming-prefixes (file)
  "Check FILE for naming convention violations (rule 1)."
  (iar--check-line-pattern
   file
   (lambda (line)
     (or (string-match-p "\\bmy-gptel--" line)
         (string-match-p "\\biar--mygptel--" line)))
   "rule 1 (naming): forbidden prefix found"))

(defun iar--check-provide-statement (file)
  "Check FILE has a provide statement (rule 9)."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (unless (re-search-forward "^(provide " nil t)
      (push (format "%s: rule 9 (provide): missing provide statement" file)
            iar--guidelines-violations))))

(defun iar--check-provide-name-matches (file)
  "Check FILE provide name matches file name (rule 9, 3)."
  (let* ((base (file-name-base file))
         (expected-system (format "iar-%s" (replace-regexp-in-string "_" "-" base)))
         (expected-tool (format "iar-tool--%s" (replace-regexp-in-string "_" "-" base))))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (when (re-search-forward "^(provide '\\([^)]+\\))" nil t)
        (let ((prov (match-string 1)))
          (unless (or (string= prov expected-system)
                      (string= prov expected-tool)
                      (string= prov base))
            (push (format "%s: rule 9 (provide): provide %s does not match file name %s"
                          file prov base)
                  iar--guidelines-violations)))))))

(defun iar--check-temp-file-prefix (file)
  "Check FILE for non-iar- temp file prefixes (rule 4)."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((line-num 0))
      (while (not (eobp))
        (cl-incf line-num)
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
          (unless (iar--line-is-comment-p line)
            (when (and (string-match-p "make-temp-file" line)
                       (not (string-match-p "make-temp-file \"iar-" line)))
              (push (format "%s:%d: rule 4 (temp files): non-iar- temp file prefix"
                            file line-num)
                    iar--guidelines-violations))))
        (forward-line 1)))))

(defun iar--check-anonymous-lambda-advice (file)
  "Check FILE for anonymous lambdas in advice-add (rule 49)."
  (iar--check-line-pattern
   file
   (lambda (line)
     (and (string-match-p "advice-add" line)
          (string-match-p "lambda" line)))
   "rule 49 (anti-pattern): anonymous lambda in advice-add"))

(defun iar--check-override-advice (file)
  "Check FILE for :override advice (rule 51)."
  (iar--check-line-pattern
   file
   (lambda (line) (string-match-p ":override" line))
   "rule 51 (anti-pattern): :override advice found"))

(defun iar--check-cl-return-from (file)
  "Check FILE for cl-return-from without explicit cl-block (rule 48)."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((has-cl-block nil)
          (has-cl-return-from nil)
          (line-num 0))
      (while (not (eobp))
        (cl-incf line-num)
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
          (unless (iar--line-is-comment-p line)
            (when (string-match-p "(cl-block" line)
              (setq has-cl-block t))
            (when (string-match-p "(cl-return-from" line)
              (setq has-cl-return-from t)
              (push (format "%s:%d: rule 48 (anti-pattern): cl-return-from without explicit cl-block"
                            file line-num)
                    iar--guidelines-violations))))
        (forward-line 1))
      (when (and has-cl-return-from (not has-cl-block))
        (push (format "%s: rule 48 (anti-pattern): cl-return-from without any cl-block" file)
              iar--guidelines-violations)))))

(defun iar--check-hardcoded-personal-data (file)
  "Check FILE for hardcoded personal data (rule 52)."
  (iar--check-line-pattern
   file
   (lambda (line)
     (string-match-p "Ignacio\\|ignacio@randazzo\\.ar" line))
   "rule 52 (security): hardcoded personal data"))

(defun iar--check-side-effects-let* (file)
  "Check FILE for side effects in let* bindings (rule 47)."
  (iar--check-line-pattern
   file
   (lambda (line)
     (string-match-p "(_ (\\(unless\\|when\\).*make-directory" line))
   "rule 47 (anti-pattern): side effect in let* binding"))

(defun iar--check-file (file)
  "Run all guidelines checks on FILE."
  (iar--check-naming-prefixes file)
  (iar--check-provide-statement file)
  (iar--check-provide-name-matches file)
  (iar--check-temp-file-prefix file)
  (iar--check-anonymous-lambda-advice file)
  (iar--check-override-advice file)
  (iar--check-cl-return-from file)
  (iar--check-hardcoded-personal-data file)
  (iar--check-side-effects-let* file))

;;;###autoload
(defun iar-check-guidelines ()
  "Check the i.ar codebase against GUIDELINES.org rules.
Prints violations to stdout. Returns t if violations found, nil otherwise."
  (interactive)
  (setq iar--guidelines-violations nil)
  (let ((files (iar--all-elisp-files)))
    (message "Checking %d files against GUIDELINES.org..." (length files))
    (dolist (file files)
      (iar--check-file file)))
  (let ((violations (nreverse iar--guidelines-violations)))
    (if (null violations)
        (progn
          (message "OK: No guidelines violations found.")
          nil)
      (message "FOUND %d guidelines violation(s):" (length violations))
      (dolist (v violations)
        (message "  %s" v))
      t)))

(provide 'iar-guidelines-checker)