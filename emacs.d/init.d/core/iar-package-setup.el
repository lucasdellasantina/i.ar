;; -*- lexical-binding: t; -*-

;;; 1. PACKAGE MANAGER SETUP
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'gptel)
  (package-install 'gptel))

(unless (package-installed-p 'undercover)
  (package-install 'undercover))

(unless (package-installed-p 'mcp)
  (package-install 'mcp))

(provide 'iar-package-setup)