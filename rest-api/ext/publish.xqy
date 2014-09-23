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
    if ( map:get($mlpm, "name") eq $package and
         map:get($mlpm, "version") eq $version )
    then
      try {
        xdmp:set-response-code(200, "OK"),
        mlpm:publish($mlpm, $input, $package, $version)
      }
      catch($ex) {
        xdmp:log($ex),
        xdmp:set-response-code(400, "Bad Request"),
        document { "Bad Request, already exists" }
      }
      (:
      let $dir := fn:string-join(("/packages", $package, $version), "/") || "/"
      return
        if (xdmp:exists(xdmp:directory($dir)))
        then (
          xdmp:set-response-code(400, "Bad Request"),
          document { "Bad Request, already exists" }
        )
        else (
          map:put($mlpm, "created", fn:current-dateTime()),
          xdmp:set-response-code(200, "OK"),
          xdmp:document-insert($dir || $package || ".zip", $input),
          xdmp:document-insert($dir || "mlpm.xml", mlpm:to-xml($mlpm))
        )
  :)
    else (
      xdmp:set-response-code(400, "Bad Request"),
      document { "Bad Request, mismatch" }
    )
};
