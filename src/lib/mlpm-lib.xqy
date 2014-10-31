xquery version "1.0-ml";

module namespace mlpm = "http://mlpm.org/ns";

import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare option xdmp:mapping "false";

declare function mlpm:to-json($xml as element()) as json:object
{
  let $conf :=
    map:new((
      json:config("custom"),
      map:entry("array-element-names", xs:QName("mlpm:versions"))))
  let $json :=
    xdmp:from-json(
      json:transform-to-json($xml, $conf))
  return map:get($json, map:keys($json)[1])
};

declare function mlpm:to-xml($json) as element()+
{
  let $conf :=
    map:new((
      json:config("custom"),
      map:entry("element-namespace-prefix", "mlpm"),
      map:entry("element-namespace", "http://mlpm.org/ns")))
  return json:transform-from-json($json, $conf)
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

declare function mlpm:find($package as xs:string) as element(mlpm:package)?
{
  cts:search(/mlpm:package, cts:element-value-query(xs:QName("mlpm:name"), $package))
};

declare function mlpm:find-version($package as xs:string, $version as xs:string?) as element(mlpm:package-version)*
{
  if ($version)
  then
    cts:search(/mlpm:package-version,
      cts:and-query((
        cts:element-value-query(xs:QName("mlpm:name"), $package),
        cts:element-value-query(xs:QName("mlpm:version"), $version))))
  else (
    for $x in cts:search(/mlpm:package-version, cts:element-value-query(xs:QName("mlpm:name"), $package))
    order by $x/mlpm:created descending
    return $x
  )[1]
};

declare function mlpm:resolve($mlpm as element(mlpm:package-version)) as map:map
{
  mlpm:resolve($mlpm, "./mlpm_modules")
};

declare function mlpm:resolve(
  $mlpm as element(mlpm:package-version),
  $path as xs:string?
) as map:map
{
  let $package := $mlpm/mlpm:name/fn:string()
  let $version := $mlpm/mlpm:version/fn:string()
  return map:new((
    map:entry("package", $package),
    map:entry("version", $version),
    map:entry("path", $path),
    if (fn:exists($mlpm/mlpm:dependencies/*))
    then
      let $deps := json:to-array((
        for $dep in $mlpm/mlpm:dependencies/*
        let $dep-mlpm := mlpm:find-version(fn:local-name($dep), $dep/fn:string())
        let $dep-path := $path || "/" || $package || "/mlpm_modules"
        (:
          if (fn:matches($path, "/$"))
          then
          else
        :)
        return mlpm:resolve($dep-mlpm, $dep-path)
      ))
      where json:array-size($deps) gt 0
      return map:entry("dependencies", $deps)
    else ()
  ))
};

declare function mlpm:get-archive($mlpm as element(mlpm:package-version)) as document-node()
{
  let $package := $mlpm/mlpm:name/fn:string()
  let $dir := mlpm:version-dir($package, $mlpm/mlpm:version/fn:string())
  return fn:doc($dir || $package || ".zip")
};

declare function mlpm:version-dir($package as xs:string, $version as xs:string) as xs:string
{
  fn:string-join(("/packages", $package, "versions", $version), "/") || "/"
};

declare function mlpm:publish(
  $mlpm as json:object,
  $input as document-node(),
  $package as xs:string,
  $version as xs:string
) {
  let $dir := mlpm:version-dir($package, $version)
  return
    if (xdmp:exists(xdmp:directory($dir)))
    then fn:error(xs:QName("VERSION-EXISTS"), ($package, $version))
    else (
      (: TODO: update /mlpm:package :)
      map:put($mlpm, "created", fn:current-dateTime()),
      xdmp:document-insert($dir || $package || ".zip", $input),
      xdmp:document-insert($dir || "mlpm.xml", element mlpm:package-version { mlpm:to-xml($mlpm) }),
      mlpm:update-package($package, $version, $mlpm)
    )
};

declare function mlpm:update-package($package, $version, $mlpm)
{
  let $doc := mlpm:find($package)
  return
    if ($doc)
    then
      let $old := mlpm:to-json($doc)
      let $mlpm :=
        map:new((
          mlpm:json-exclude($mlpm, "version"),
          map:entry("versions", json:to-array((
            json:array-values(map:get($old, "versions")),
            $version
          ))),
          map:entry("time", map:new((
            map:get($old, "time"),
            map:entry("modified", fn:current-dateTime())
          )))
        ))
      return
        xdmp:document-insert(
          $doc/fn:base-uri(.),
          element mlpm:package { mlpm:to-xml($mlpm) })
    else
      let $mlpm :=
        map:new((
          mlpm:json-exclude($mlpm, "version"),
          map:entry("versions", json:to-array($version)),
          map:entry("time", map:new((
            map:entry("created", fn:current-dateTime()),
            map:entry("modified", fn:current-dateTime()))
          ))))
      return
        xdmp:document-insert(
          "/packages/" || $package || "/package.xml",
          element mlpm:package { mlpm:to-xml($mlpm) })
};
