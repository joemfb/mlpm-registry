xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/user-token";

import module namespace user = "http://mlpm.org/ns/user" at "/lib/user-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("username=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),

  (: TODO: assert privileged (rest-writer)? :)

  let $username := map:get($params, "$username")
  let $user := user:find($username)
  return
    if (fn:exists($user))
    then (
      map:put($context, "output-status", (200, "Ok")),
      document { xdmp:to-json( user:to-json($user/user:token) ) }
    )
    else (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
};

declare
  %roxy:params("username=xs:string")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/json"),

  (: TODO: assert privileged (rest-writer)? :)

  let $username := map:get($params, "username")
  let $user := user:find($username)
  return
    if (fn:exists($user))
    then (
      map:put($context, "output-status", (200, "Ok")),

      let $updated := user:revoke-token($user)
      return (
        user:save-user($updated),
        document { xdmp:to-json( user:to-json($updated/user:token) ) }
      )
    )
    else (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
};
