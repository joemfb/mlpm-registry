xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/unpublish";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("package=xs:string", "version=xs:string?")
function ext:post(
  $context as map:map,
  $params  as map:map,
  $input   as document-node()*
) as document-node()*
{
  let $package-name := map:get($params, "package")
  let $version := map:get($params, "version")

  let $package := mlpm:find($package-name)
  return
    if (fn:exists($package))
    then (
      map:put($context, "output-status", (200, "Ok")),
      mlpm:unpublish($package, $version)
    )
    else (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
};
