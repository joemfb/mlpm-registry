xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/publish";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("package=xs:string", "version=xs:string")
function ext:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  map:put($context, "output-types", "application/json"),

  (: TODO: scan the manifest for mlpm.(json|xml) (at any level?) :)
  let $mlpm := xdmp:from-json( xdmp:zip-get($input, "mlpm.json") )
  let $package := map:get($params, "package")
  let $version := map:get($params, "version")
  return
    (: TODO:, does this make any sense? :)
    if ( map:get($mlpm, "name") eq $package and
         map:get($mlpm, "version") eq $version )
    then
      try {
        map:put($context, "output-status", (200, "Ok")),
        mlpm:publish($mlpm, $input, $package, $version)
      }
      catch($ex) {
        xdmp:log($ex),
        map:put($context, "output-status", (400, "Bad Request")),
        document { "Bad Request, version already exists" }
      }
    else (
      map:put($context, "output-status", (400, "Bad Request")),
      document { "Bad Request, mismatch" }
    )
};
