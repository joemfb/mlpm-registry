xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/resolve";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("package=xs:string", "version=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),
  let $package := map:get($params, "package")
  let $version := map:get($params, "version")
  let $mlpm := mlpm:find-version($package, $version)
  return
    if (fn:exists($mlpm))
    then (
      xdmp:set-response-code(200, "OK"),
      document { mlpm:resolve($mlpm) ! xdmp:to-json(.) }
    )
    else (
      xdmp:set-response-code(404, "Not Found"),
      document { "Not Found" }
    )
};
