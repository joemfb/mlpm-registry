xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/download";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("package=xs:string", "version=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $package := map:get($params, "package")
  let $version := map:get($params, "version")

  let $mlpm := mlpm:find-version($package, $version)
  return
    if (fn:exists($mlpm))
    then (
      xdmp:set-response-code(200, "OK"),
      map:put($context, "output-types", xdmp:uri-content-type($mlpm/fn:base-uri())),
      xdmp:add-response-header("Content-Disposition", "attachment;filename=" || $package || ".zip"),
      mlpm:get-archive($mlpm)
    )
    else (
      xdmp:set-response-code(404, "Not Found"),
      document { "Not Found" }
    )
};
