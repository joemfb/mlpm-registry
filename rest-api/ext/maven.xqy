xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/maven";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare option xdmp:mapping "false";

declare
  %roxy:params("path=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $path := map:get($params, "path")
  let $tokens := fn:tokenize($path, "/")[. ne ""]
  let $request := $tokens[fn:last()]
  let $package-name :=
    if ($request eq "maven-metadata.xml")
    then $tokens[fn:last() - 1]
    else $tokens[fn:last() - 2]

  let $version :=
    if ($request eq "pom.xml" or fn:matches($request, "\.zip$"))
    then
      let $val := $tokens[fn:last() - 1]
      where fn:exists($val) and fn:exists(mlpm:find-version($package-name, $val))
      return $val
    else ()

  let $package := mlpm:find( $package-name )

  (:
  let $valid-request :=
    ($request = ("maven-metadata.xml", "pom.xml") or
    fn:matches($request, "\.zip$")) and
    fn:exists($package) and
    (if ($request eq "pom.xml")
    then fn:exists($package-version)
    else fn:true())
  :)

  return
    if ($request eq "maven-metadata.xml")
    then (
      map:put($context, "output-types", "application/xml"),
      map:put($context, "output-status", (200, "Ok")),
      document { mlpm:maven-metadata($package) }
    )
    else
      if ($request eq "pom.xml")
      then (
        map:put($context, "output-types", "application/xml"),
        map:put($context, "output-status", (200, "Ok")),
        document { mlpm:maven-pom($package, $version) }
      )
      else
        if (fn:matches($request, "\.zip$"))
        then (
          map:put($context, "output-status", (301, "Redirect")),
          xdmp:add-response-header("Location", "/v1/resources/download?rs:package=" || $package-name || "&amp;rs:version=" || $version)
        )
        else (
          map:put($context, "output-types", "application/json"),
          map:put($context, "output-status", (404, "Not Found")),
          document { "Not Found" }
        )
};
