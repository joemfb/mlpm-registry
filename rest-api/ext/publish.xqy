xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/publish";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace error = "http://marklogic.com/xdmp/error";

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
  let $package-metadata := xdmp:from-json( xdmp:zip-get($input, "mlpm.json") )

  let $package-name := map:get($params, "package")
  let $version := map:get($params, "version")
  return
    (: TODO:, does this make any sense? :)
    if ( map:get($package-metadata, "name") eq $package-name and
         map:get($package-metadata, "version") eq $version )
    then
      try {
        map:put($context, "output-status", (200, "Ok")),
        mlpm:publish($package-metadata, $input, $package-name, $version)
      }
      catch($ex) {
        if ($ex/error:name = ("VERSION-EXISTS", "MISSING-DEPENDENCY"))
        then (
          map:put($context, "output-status", (400, "Bad Request")),
          document { "Bad Request, " || $ex/error:format-string }
        )
        else xdmp:rethrow()
      }
    else (
      map:put($context, "output-status", (400, "Bad Request")),
      document { "Bad Request, mismatch" }
    )
};
