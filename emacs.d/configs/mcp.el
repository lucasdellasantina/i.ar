;; -*- lexical-binding: t; -*-

;;; MCP Server Configuration
;;
;; Defines known MCP servers and their connection details.
;; Project files reference servers by name via #+MCP: burp
;; The assembly engine reads #+MCP and the agent loader activates
;; the listed servers at session start.
;;
;; Server config format (alist):
;;   (("burp" . (:url "http://localhost:9876/sse"))
;;    ("my-server" . (:command "my-mcp-server" :args ("--flag"))))
;;
;; :url -- SSE transport (remote server, HTTP)
;; :command + :args -- stdio transport (local server process)

(require 'cl-lib)
(require 'subr-x)

(defcustom iar-mcp-servers
  '(("burp" . (:url "http://localhost:9876/sse")))
  "Alist of known MCP servers available to i.ar agents.
Each entry is (NAME . CONFIG) where CONFIG is a plist with either:
- :url URL -- for SSE transport (HTTP server like Burp Suite)
- :command CMD :args (ARGS...) -- for stdio transport (local process)
Project files reference servers by name via #+MCP: burp other-server"
  :type '(alist :key-type string
                :value-type (plist :options ((:url string)
                                              (:command string)
                                              (:args (repeat string))
                                              (:timeout integer))))
  :group 'iar)

(defcustom iar-mcp-auto-start t
  "Whether to automatically start MCP servers when a session begins.
When non-nil, servers listed in the project's #+MCP are started
and their tools registered before the agent is ready.
When nil, servers must be started manually via `iar-mcp-start'."
  :type 'boolean
  :group 'iar)

(provide 'iar-config-mcp)