xquery version "1.0-ml";

module namespace trns = "http://marklogic.com/rest-api/transform/mlpm";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare function trns:transform(
  $context as map:map,
  $params as map:map,
  $content as document-node()
) as document-node()
{
  document {
    let $json := mlpm:to-json($content/mlpm:package)
    let $_ :=
      let $pom := mlpm:maven-pom($content/mlpm:package)
      where fn:exists($pom)
      return
        map:put($json, "maven-pom",
          xdmp:quote(
            <dependency xmlns="http://maven.apache.org/POM/4.0.0">{
              $pom/(groupId|artifactId|version)
            }</dependency>,
            <options xmlns="xdmp:quote">
              <indent-untyped>yes</indent-untyped>
            </options>))
    return xdmp:to-json( $json )
  }
};
