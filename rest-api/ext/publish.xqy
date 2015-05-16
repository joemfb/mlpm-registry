xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/publish";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";
import module namespace user = "http://mlpm.org/ns/user" at "/lib/user-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace error = "http://marklogic.com/xdmp/error";

declare option xdmp:mapping "false";

declare
  %roxy:params("token=xs:string", "sha2sum=xs:string?")
function ext:put(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()?
{
  map:put($context, "output-types", "application/json"),
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/rest-writer", "execute"),

  let $token := map:get($params, "token")
  let $user := user:find-by-token($token)

  let $sha2sum := map:get($params, "sha2sum")

  (: TODO: at some future point, rewrite to require sha2sum :)
  let $_ :=
    if (fn:not($sha2sum))
    (: TODO: get name :)
    then xdmp:log("missing sha2sum")
    else
      if (xdmp:host-get-ssl-fips-enabled(xdmp:host())) then ()
      else
        let $actual := xdmp:sha256($input/binary())
        return
          if ($actual eq $sha2sum) then ()
          else fn:error((), "SHA2SUM-MISMATCH", "expected " || $sha2sum || "; got " || $actual)

  return
    try {
      map:put($context, "output-status", (200, "Ok")),
      (: TODO: include sha2sum :)
      mlpm:publish($input, $user/user:username)
    }
    catch($ex) {
      if ($ex/error:name = ("VERSION-EXISTS", "UNPUBLISHED-EXISTS", "MISSING-DEPENDENCY"))
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
  %roxy:params("package=xs:string", "version=xs:string?", "force-delete=xs:boolean", "token=xs:string")
function ext:delete(
  $context as map:map,
  $params  as map:map
) as document-node()?
{
  map:put($context, "output-types", "application/json"),
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/rest-writer", "execute"),

  let $package-name := map:get($params, "package")
  let $version := map:get($params, "version")
  let $force-delete := map:get($params, "force-delete") cast as xs:boolean
  let $token := map:get($params, "token")

  let $user := user:find-by-token($token)
  let $package := mlpm:find($package-name)
  return
    if ( fn:not(fn:exists($package)) )
    then
      if (mlpm:unpublished-exists($package-name))
      then (
        map:put($context, "output-status", (410, "Unpublished")),
        document { "Unpublished" }
      )
      else (
        map:put($context, "output-status", (404, "Not Found")),
        document { "Not Found" }
      )
    else
      try {
        map:put($context, "output-status", (200, "Ok")),
        mlpm:unpublish($package, $version, $force-delete, $user/user:username)
        }
      catch($ex) {
        if ($ex/error:name = ("UNPRIVILEGED"))
        then (
          map:put($context, "output-status", (401, "Not Authorized")),
          document { "Not Authorized, " || $ex/error:format-string }
        )
        else
          if ($ex/error:name = ("UNPUBLISH-NO-FORCE"))
          then (
            map:put($context, "output-status", (400, "BAD-REQUEST")),
            document { "Not Authorized, " || $ex/error:format-string }
          )
          else xdmp:rethrow()
      }
};
