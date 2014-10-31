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
   xdmp:to-json( mlpm:to-json($content/*) )
  }
};
