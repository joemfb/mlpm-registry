xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/authenticate";

import module namespace user = "http://mlpm.org/ns/user" at "/lib/user-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("token=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/rest-writer", "execute"),

  let $token := map:get($params, "token")
  let $user := user:find-by-token($token)
  return
    if (fn:not(fn:exists($user)))
    then (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
    else (
      map:put($context, "output-status", (200, "Ok")),
      document {
        xdmp:to-json(map:new((
          map:entry("username", $user/user:username/fn:string()),
          map:entry("name", $user/user:name/fn:string()),
          map:entry("email", $user/user:emails/user:email[1]/fn:string()),
          map:entry("token", $user/user:token/fn:string())
        )))
      }
    )
};