xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/system-packages";

declare namespace mlpm = "http://mlpm.org/ns";
declare namespace roxy = "http://marklogic.com/roxy";

declare function ext:can-claim-package(
  $package as element(mlpm:package),
  $username as xs:string
) as xs:boolean
{
  let $gh-user := fn:replace($package/mlpm:repository, "^.*github.com/(.*)/.*$", "$1")
  return $package/mlpm:author eq "system" and $gh-user eq $username
};

declare function ext:system-packages($username as xs:string)
{
  for $package in /mlpm:package[mlpm:author eq "system"][fn:contains(mlpm:repository, "github")]
  let $name := $package/mlpm:name/fn:string()
  let $gh-user := fn:replace($package/mlpm:repository, "^.*github.com/(.*)/.*$", "$1")
  where $gh-user eq $username
  order by $name
  return
    map:new((
      map:entry("name", $name),
      map:entry("repo", $package/mlpm:repository/fn:string()),
      map:entry("uri", $package/fn:base-uri(.))))
};

declare
  %roxy:params("username=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/json"),
  map:put($context, "output-status", (200, "Ok")),

  let $username := map:get($params, "username")
  return
    document {
      xdmp:to-json(
        json:to-array(
          ext:system-packages($username)))
    }
};

declare
  %roxy:params("username=xs:string", "uri=xs:string")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/json"),

  let $username := map:get($params, "username")
  let $uri := map:get($params, "uri")
  let $package := fn:doc($uri)/mlpm:package
  return
    if (fn:not(fn:exists($package)))
    then (
      map:put($context, "output-status", (404, "Not Found")),
      document { "Not Found" }
    )
    else
      if (ext:can-claim-package($package, $username))
      then (
        map:put($context, "output-status", (200, "Ok")),
        xdmp:node-replace($package/mlpm:author, element mlpm:author { $username }),
        document { () }
      )
      else (
        map:put($context, "output-status", (400, "Bad Request")),
        document { "user " || $username || " can't claim package " || $uri }
      )
};
