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

  let $package-name := map:get($params, "package")
  let $package := mlpm:find($package-name)
  return
    if (fn:exists($package))
    then (
      map:put($context, "output-status", (200, "Ok")),

      let $json := mlpm:to-json($package)
      return (
        map:delete($json, "readme"),
        map:delete($json, "parsed-readme"),
        document { xdmp:to-json( $json ) }
      )
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
