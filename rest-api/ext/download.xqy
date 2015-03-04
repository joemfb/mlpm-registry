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
  let $package-name := map:get($params, "package")
  let $version := map:get($params, "version")

  let $package := mlpm:find-version($package-name, $version)
  return
    if (fn:exists($package))
    then (
      map:put($context, "output-status", (200, "Ok")),
      map:put($context, "output-types", xdmp:uri-content-type($package/fn:base-uri())),
      xdmp:add-response-header("Content-Disposition", "attachment;filename=" || $package-name || "-" || $version || ".zip"),
      fn:doc(mlpm:get-archive-uri($package))
    )
    else
      if (mlpm:unpublished-version-exists($package-name, $version))
      then (
        map:put($context, "output-status", (410, "Unpublished")),
        document { "Unpublished" }
      )
      else (
        map:put($context, "output-status", (404, "Not Found")),
        document { "Not Found" }
      )
};
