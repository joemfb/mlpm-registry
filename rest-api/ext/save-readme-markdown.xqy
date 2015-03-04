xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/save-readme-markdown";

declare namespace mlpm = "http://mlpm.org/ns";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace html = "http://www.w3.org/1999/xhtml";

declare
  %roxy:params("uri=xs:string")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),

  let $uri := map:get($params, "uri")
  let $doc := fn:doc($uri)/*
  let $readme := xdmp:tidy($input)//html:body
  let $fn :=
    if (fn:exists($doc/mlpm:parsed-readme))
    then xdmp:node-replace($doc/mlpm:parsed-readme, ?)
    else xdmp:node-insert-child($doc, ?)
  return (
    $fn( element mlpm:parsed-readme { $readme } ),
    xdmp:node-delete($doc/mlpm:readme),
    document { "" }
  )
};
