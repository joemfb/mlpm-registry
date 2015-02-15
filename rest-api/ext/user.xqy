xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/user";

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

  let $username := map:get($params, "$username")
  let $user := user:find($username)
  return
    if (fn:exists($user))
    then (
      map:put($context, "output-status", (200, "Ok")),
      user:to-json($user)
    )
    else (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
};

declare function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/json"),

  let $json := xdmp:from-json($input)
  let $username := map:get($json, "username")
  let $user :=
    let $x := user:find($username)
    return
      if (fn:exists($x))
      then user:update-user($x, $json)
      else user:create-user($json)
  return (
    map:put($context, "output-status", (200, "Ok")),
    (: TODO: always update? :)
    user:save-user($user),
    document { xdmp:to-json( user:to-json($user) ) }
  )
};
