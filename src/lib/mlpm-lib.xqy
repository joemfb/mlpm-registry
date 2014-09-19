xquery version "1.0-ml";

module namespace mlpm = "http://mlpm.org/ns";

import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare option xdmp:mapping "false";

declare function mlpm:to-json($xml as element(mlpm:mlpm)) as json:object
{
  let $json := json:transform-to-json($xml, json:config("custom"))
  return map:get(xdmp:from-json($json), "mlpm")
};

declare function mlpm:to-xml($json as json:object?) as element(mlpm:mlpm)
{
  let $conf :=
    map:new((
      json:config("custom"),
      map:entry("element-namespace-prefix", "mlpm"),
      map:entry("element-namespace", "http://mlpm.org/ns")))
  return element mlpm:mlpm { json:transform-from-json($json, $conf) }
};

declare function mlpm:json-exclude($obj as json:object, $exclude as xs:string*) as json:object
{
  let $new-obj := json:object()
  let $_ := (
    for $key in map:keys($obj)[fn:not(. = $exclude)]
    return map:put($new-obj, $key, map:get($obj, $key))
  )
  return $new-obj
};

declare function mlpm:find($package as xs:string, $version as xs:string?) as element(mlpm:mlpm)*
{
  let $version-query := cts:element-value-query(xs:QName("mlpm:version"), $version)[$version]
  return
    for $x in
      cts:search(/mlpm:mlpm,
        cts:and-query(($version-query,
          cts:element-value-query(xs:QName("mlpm:name"), $package))))
    order by xs:dateTime($x/mlpm:created) descending
    return $x
};

declare function mlpm:resolve($mlpm as element(mlpm:mlpm)) as map:map
{
  let $package := $mlpm/mlpm:name/fn:string()
  let $version := $mlpm/mlpm:version/fn:string()
  return
  map:new((
    map:entry("package", $package),
    map:entry("version", $version),
    if (fn:exists($mlpm/mlpm:dependencies/*))
    then
      let $arr :=
        json:to-array((
          for $dep in $mlpm/mlpm:dependencies/*
          return mlpm:resolve(mlpm:find(fn:local-name($dep), $dep/fn:string()))))
      return
        if (json:array-size($arr) gt 0)
        then map:entry("dependencies", $arr)
        else ()
    else ()
  ))
};

declare function mlpm:get-archive($mlpm as element(mlpm:mlpm)) as document-node()
{
  let $package := $mlpm/mlpm:name/fn:string()
  let $dir := mlpm:dir($package, $mlpm/mlpm:version/fn:string())
  return fn:doc($dir || $package || ".zip")
};

declare function mlpm:dir($package as xs:string, $version as xs:string) as xs:string
{
  fn:string-join(("/packages", $package, $version), "/") || "/"
};

declare function mlpm:publish(
  $mlpm as json:object,
  $input as document-node(),
  $package as xs:string,
  $version as xs:string
) {
  let $dir := mlpm:dir($package, $version)
  return
    if (xdmp:exists(xdmp:directory($dir)))
    then fn:error(xs:QName("VERSION-EXISTS"), ($package, $version))
    else (
      map:put($mlpm, "created", fn:current-dateTime()),
      xdmp:document-insert($dir || $package || ".zip", $input),
      xdmp:document-insert($dir || "mlpm.xml", mlpm:to-xml($mlpm))
    )
};

declare function mlpm:info($docs as element(mlpm:mlpm)+) as json:object
{
  let $mlpm := mlpm:to-json($docs[1])
  let $result := mlpm:json-exclude($mlpm, "version")

  let $versions := json:to-array($docs/mlpm:version/fn:string())
  let $timestamps := $docs/mlpm:created/fn:string()
  let $time := json:object()
  let $created := json:object()
  let $_ := (
    for $doc in $docs
    return map:put($created, $doc/mlpm:version/fn:string(), $doc/mlpm:created/fn:string()),
    map:put($time, "created", $created),
    map:put($time, "modified", $docs[1]/mlpm:created/fn:string()),
    map:put($result, "time", $time),
    map:put($result, "versions", $versions)
  )
  return $result
};
