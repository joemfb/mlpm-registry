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

  let $package-name := map:get($params, "package")
  let $semver := map:get($params, "version")
  let $package-version := mlpm:find-semver($package-name, $semver)
  return
    if (fn:exists($package-version))
    then (
      map:put($context, "output-status", (200, "Ok")),
      document {
       xdmp:to-json( mlpm:resolve($package-version) )
      }
    )
    else
      if (mlpm:unpublished-exists($package-name))
      then (
        map:put($context, "output-status", (410, "Unpublished")),
        document { "Unpublished" }
      )
      else (
        map:put($context, "output-status", (404, "Not Found")),
        document { "Not Found" }
      )
};
