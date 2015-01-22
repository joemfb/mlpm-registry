xquery version "1.0-ml";

module namespace mlpm = "http://mlpm.org/ns";

import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare variable $mlpm:doc-permissions := (
  xdmp:permission("mlpm-registry-role", "read"),
  xdmp:permission("mlpm-registry-writer", "update")
);

declare option xdmp:mapping "false";

declare function mlpm:to-json($xml as element()) as json:object
{
  let $conf := json:config("custom")
  let $json :=
    xdmp:from-json(
      json:transform-to-json($xml, $conf))
  (: discard root property :)
  let $json := map:get($json, map:keys($json)[1])

  let $_ := (
    (: convert dependency name/semver pairs to properties :)
    if (map:contains($json, "dependencies"))
    then
      map:put($json, "dependencies", map:new((
        for $dep in $xml/mlpm:dependencies/mlpm:dependency
        return
          map:entry(
            $dep/mlpm:package-name/fn:string(),
            $dep/mlpm:semver/fn:string()))))
    else map:put($json, "dependencies", json:object()),

    (: handle version arrays :)
    if (map:contains($json, "versions"))
    then
      map:put($json, "versions",
       json:to-array(
         $xml/mlpm:versions/descendant-or-self::mlpm:*[fn:not(*)]/fn:string()))
    else ()
  )
  return $json
};

declare function mlpm:to-xml($json) as element()+
{
  (: clone to avoid side effects (ugh) :)
  let $json := mlpm:json-clone($json, ())

  let $conf := map:new((
    json:config("custom"),
    map:entry("element-namespace-prefix", "mlpm"),
    map:entry("element-namespace", "http://mlpm.org/ns")
  ))

  let $_ :=
    if (map:contains($json, "versions"))
    then
      map:put($json, "versions",
        map:entry("_children",
          json:to-array(
            for $version in json:array-values(map:get($json, "versions"))
            return
              map:entry("version",
                map:entry("_value", $version)))))
    else ()

  let $deps := map:get($json, "dependencies")
  let $_ :=
    if (fn:exists($deps) and map:keys($deps))
    then
      map:put($json, "dependencies",
        map:entry("_children",
          json:to-array(
            for $dep in map:keys($deps)
            return
              map:entry("dependency",
                map:new((
                  map:entry("package-name",
                    map:entry("_value", $dep)),
                  map:entry("semver",
                    map:entry("_value", map:get($deps, $dep)))))))))
    else map:delete($json, "dependencies")

  return json:transform-from-json($json, $conf)
};

declare function mlpm:json-clone(
  $obj as json:object,
  $exclude as xs:string*
) as json:object
{
  xdmp:from-json(
    xdmp:to-json(
      map:new((
        for $key in map:keys($obj)[fn:not(. = $exclude)]
        return map:entry($key, map:get($obj, $key))))))
};

declare function mlpm:find($package-name as xs:string) as element(mlpm:package)?
{
  cts:search(/mlpm:package,
    cts:and-query((
      cts:collection-query("http://mlpm.org/ns/collection/published"),
      cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name))), "unfiltered")
};

declare function mlpm:find-version(
  $package-name as xs:string,
  $version as xs:string?
) as element(mlpm:package-version)*
{
  if ($version eq "latest")
  then (
    for $x in
      cts:search(/mlpm:package-version,
        cts:and-query((
          cts:collection-query("http://mlpm.org/ns/collection/published"),
          cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name))), "unfiltered")
    order by $x/mlpm:created descending
    return $x
  )[1]
  else
    cts:search(/mlpm:package-version,
      cts:and-query((
        cts:collection-query("http://mlpm.org/ns/collection/published"),
        cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name),
        cts:element-range-query(xs:QName("mlpm:version"), "=", $version))), "unfiltered")
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
  let $package-name := $mlpm/mlpm:name/fn:string()
  let $version := $mlpm/mlpm:version/fn:string()
  return map:new((
    map:entry("package", $package-name),
    map:entry("version", $version),
    map:entry("path", $path),
    if (fn:exists($mlpm/mlpm:dependencies/*))
    then
      let $deps := json:to-array((
        for $dep in $mlpm/mlpm:dependencies/*
        let $dep-mlpm := mlpm:find-version($dep/mlpm:package-name/fn:string(), $dep/mlpm:semver/fn:string())
        let $dep-path := $path || "/" || $package-name || "/mlpm_modules"
        return mlpm:resolve($dep-mlpm, $dep-path)
      ))
      where json:array-size($deps) gt 0
      return map:entry("dependencies", $deps)
    else ()
  ))
};

declare function mlpm:get-archive-uri($mlpm as element(mlpm:package-version)) as xs:string
{
  let $package-name := $mlpm/mlpm:name/fn:string()
  let $dir := mlpm:version-dir($package-name, $mlpm/mlpm:version/fn:string())
  return $dir || $package-name || ".zip"
};

declare function mlpm:version-dir(
  $package-name as xs:string,
  $version as xs:string
) as xs:string
{
  fn:string-join(("/packages", $package-name, "versions", $version), "/") || "/"
};

declare function mlpm:valid-deps($deps as map:map) as xs:boolean
{
  fn:fold-left(
    function($a, $b) { $a and $b },
    fn:true(),
    for $dep in map:keys($deps)
    let $semver := map:get($deps, $dep)
    return
      if (fn:exists(mlpm:find-version($dep, $semver)))
      then fn:true()
      else fn:error(xs:QName("MISSING-DEPENDENCY"), "dependency doesn't exist", $dep || "@" || $semver))
};

declare function mlpm:publish(
  $mlpm as json:object,
  $input as document-node(),
  $package-name as xs:string,
  $version as xs:string
) {
  (: TODO: validate author/maintainer :)
  if (fn:false())
  then fn:error(xs:QName("UNPRIVILEGED"), "$user is not allowed to modify " || $package-name)
  else
    if (fn:string-length($version) eq 0)
    then fn:error(xs:QName("NO-VERSION"), "no version specificed", $package-name)
    else
      if (fn:exists(mlpm:find-version($package-name, $version)))
      then fn:error(xs:QName("VERSION-EXISTS"), "version already exists", ($package-name, $version))
      else
        let $deps := map:get($mlpm, "dependencies")
        return
          if ( fn:not(map:count($deps)) or (map:count($deps) and mlpm:valid-deps($deps)) )
          then (
            mlpm:save-version($mlpm, $input, $package-name, $version),
            mlpm:save-package($package-name,
              mlpm:update-package($package-name, $version, $mlpm))
          )
          (: Error propogated from mlpm:valid-deps :)
          else ()
};

declare function mlpm:update-package(
  $package-name as xs:string,
  $version as xs:string,
  $mlpm as json:object
) as json:object
{
  let $doc := mlpm:find($package-name)
  let $mlpm :=
    if ($doc)
    then
      let $old := mlpm:to-json($doc)
      return
        map:new((
          mlpm:json-clone($mlpm, "version"),
          map:entry("versions", json:to-array((
            json:array-values(map:get($old, "versions")),
            $version
          ))),
          map:entry("time", map:new((
            map:get($old, "time"),
            map:entry("modified", fn:current-dateTime())
          )))
        ))
    else
      map:new((
        mlpm:json-clone($mlpm, "version"),
        map:entry("versions", json:to-array($version)),
        map:entry("created", fn:current-dateTime()),
        map:entry("time", map:new((
          map:entry("created", fn:current-dateTime()),
          map:entry("modified", fn:current-dateTime()))
        ))))
  return xdmp:from-json( xdmp:to-json( $mlpm ) )
};

declare function mlpm:save-package(
  $package-name as xs:string,
  $mlpm as json:object
)
{
  xdmp:document-insert(
    "/packages/" || $package-name || "/package.xml",
    element mlpm:package { mlpm:to-xml($mlpm) },
    $mlpm:doc-permissions,
    ("http://mlpm.org/ns/collection/published",
    "http://mlpm.org/ns/collection/package"))
};

declare function mlpm:save-version(
  $mlpm as json:object,
  $input as document-node(),
  $package-name as xs:string,
  $version as xs:string
)
{
  let $dir := mlpm:version-dir($package-name, $version)
  return (
    map:put($mlpm, "created", fn:current-dateTime()),
    xdmp:document-insert(
      $dir || $package-name || ".zip",
      $input,
      $mlpm:doc-permissions,
      ("http://mlpm.org/ns/collection/published",
      "http://mlpm.org/ns/collection/package-archive")),
    xdmp:document-insert(
      $dir || "mlpm.xml",
      element mlpm:package-version { mlpm:to-xml($mlpm) },
      $mlpm:doc-permissions,
      ("http://mlpm.org/ns/collection/published",
      "http://mlpm.org/ns/collection/package-version"))
  )
};

declare function mlpm:unpublish($package as element(mlpm:package), $version as xs:string?)
{
  (: TODO: validate author/maintainer :)
  let $versions :=
    if ($version)
    then $version
    else $package/mlpm:versions/mlpm:version/fn:string()
  return (
    for $x in $versions
    let $package-version := mlpm:find-version($package/mlpm:name, $x)
    let $uris := (
      $package-version/fn:base-uri(.),
      mlpm:get-archive-uri($package-version)
    )
    return $uris ! mlpm:unpublish-uri(.)
    ,
    if (fn:not($version) or fn:count($versions) eq 1)
    then mlpm:unpublish-uri($package/fn:base-uri(.))
    else ()
  )
};

declare function mlpm:unpublish-uri($uri as xs:string)
{
  let $collections := (
    xdmp:document-get-collections($uri)[. ne "http://mlpm.org/ns/collection/published"],
    "http://mlpm.org/ns/collection/unpublished"
  )
  return xdmp:document-set-collections($uri, $collections)
};
