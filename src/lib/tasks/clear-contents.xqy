xquery version "1.0-ml";

declare namespace mlpm = "http://mlpm.org/ns";

/mlpm:package-version/mlpm:readme ! xdmp:node-delete(.),
cts:uri-match("*/contents/*") ! xdmp:document-delete(.)
