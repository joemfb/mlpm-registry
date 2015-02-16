xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/publish";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";
import module namespace user = "http://mlpm.org/ns/user" at "/lib/user-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace error = "http://marklogic.com/xdmp/error";

declare
  %roxy:params("token=xs:string")
function ext:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  map:put($context, "output-types", "application/json"),

  (: TODO: assert privileged (rest-writer)? :)

  let $token := map:get($params, "token")
  let $user := user:find-by-token($token)
  return
    try {
      map:put($context, "output-status", (200, "Ok")),
      mlpm:publish($input, $user/user:username)
    }
    catch($ex) {
      if ($ex/error:name = ("VERSION-EXISTS", "MISSING-DEPENDENCY"))
      then (
        map:put($context, "output-status", (400, "Bad Request")),
        document { "Bad Request, " || $ex/error:format-string }
      )
      else
        if ($ex/error:name = ("UNPRIVILEGED"))
        then (
          map:put($context, "output-status", (401, "Not Authorized")),
          document { "Not Authorized, " || $ex/error:format-string }
        )
        else xdmp:rethrow()
    }
};

declare
  %roxy:params("package=xs:string", "version=xs:string?", "token=xs:string")
function ext:delete(
  $context as map:map,
  $params  as map:map
) as document-node()?
{
  map:put($context, "output-types", "application/json"),

  (: TODO: assert privileged (rest-writer)? :)

  let $package-name := map:get($params, "package")
  let $version := map:get($params, "version")
  let $token := map:get($params, "token")

  let $user := user:find-by-token($token)
  let $package := mlpm:find($package-name)
  return
    if ( fn:not(fn:exists($package)) )
    then (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
    else
      try {
        map:put($context, "output-status", (200, "Ok")),
        mlpm:unpublish($package, $version, $user/user:username)
        }
      catch($ex) {
        if ($ex/error:name = ("UNPRIVILEGED"))
        then (
          map:put($context, "output-status", (401, "Not Authorized")),
          document { "Not Authorized, " || $ex/error:format-string }
        )
        else xdmp:rethrow()
      }
};
