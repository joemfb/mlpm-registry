xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/info";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("package=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),
  let $package := map:get($params, "package")
  let $docs := mlpm:find($package, ())
  return
    if (fn:exists($docs))
    then (
      xdmp:set-response-code(200, "OK"),
      document { xdmp:to-json( mlpm:info($docs) ) }
    )
    else (
      xdmp:set-response-code(404, "Not Found"),
      document { "Not Found" }
    )
};
