xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/user";

import module namespace user = "http://mlpm.org/ns/user" at "/lib/user-lib.xqy";
import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare
  %roxy:params("username=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),

  let $username := map:get($params, "username")
  let $user := user:find($username)
  return
    if (fn:exists($user))
    then (
      map:put($context, "output-status", (200, "Ok")),
      let $json := user:to-json($user)
      let $_ := (
        map:put($json, "packages", json:to-array(
          for $project in mlpm:find-by-author($username)
          return map:entry("name", $project/mlpm:name/fn:string())
        )),
        map:put($json, "github-profile",
          map:get(map:get($json, "github-data"), "html-url")),
        map:delete($json, "github-data"),
        map:delete($json, "token")
      )
      return document { xdmp:to-json( $json ) }
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
  xdmp:security-assert("http://marklogic.com/xdmp/privileges/rest-writer", "execute"),

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
