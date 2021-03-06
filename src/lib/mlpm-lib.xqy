xquery version "1.0-ml";

module namespace mlpm = "http://mlpm.org/ns";

import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare namespace xsi = "http://www.w3.org/2001/XMLSchema-instance";
declare namespace mvn ="http://maven.apache.org/POM/4.0.0";
declare namespace zip = "xdmp:zip";

declare variable $mlpm:doc-permissions := (
  xdmp:permission("mlpm-registry-role", "read"),
  xdmp:permission("mlpm-registry-writer-role", "update")
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
    else (),

    (: handle readme :)
    if (map:contains($json, "parsed-readme"))
    then
      map:put($json, "parsed-readme",
        xdmp:quote(
          $xml/mlpm:parsed-readme/node(),
          <options xmlns="xdmp:quote">
            <indent-untyped>yes</indent-untyped>
          </options>))
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

    (: TODO: handle readme? :)

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

declare function mlpm:find-by-author($username as xs:string) as element(mlpm:package)*
{
  cts:search(/mlpm:package,
    cts:and-query((
      cts:collection-query("http://mlpm.org/ns/collection/published"),
      cts:element-range-query(xs:QName("mlpm:author"), "=", $username))), "unfiltered")
};

declare function mlpm:find-dependants($package-name as xs:string) as element(mlpm:package)*
{
  cts:search(/mlpm:package,
    cts:and-query((
      cts:collection-query("http://mlpm.org/ns/collection/published"),
      cts:element-range-query(xs:QName("mlpm:package-name"), "=", $package-name))), "unfiltered")
};

declare function mlpm:find-version(
  $package-name as xs:string,
  $version as xs:string
) as element(mlpm:package-version)?
{
  cts:search(/mlpm:package-version,
    cts:and-query((
      cts:collection-query("http://mlpm.org/ns/collection/published"),
      cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name),
      cts:element-range-query(xs:QName("mlpm:version"), "=", $version))), "unfiltered")
};

declare function mlpm:semver-is-specific-release($semver)
{
  fn:matches($semver, "^\d+\.\d+\.\d+$")
};

declare function mlpm:semver-is-prerelease($semver)
{
  fn:matches($semver, "^\d+\.\d+\.\d+-.*$")
};

declare function mlpm:semver-latest($name as xs:string, $semver as xs:string) as xs:string?
{
  if (mlpm:semver-is-specific-release($semver) or mlpm:semver-is-prerelease($semver))
  then $semver
  else
    cts:value-match(
      cts:element-reference(xs:QName("mlpm:version")),
      fn:replace( fn:replace($semver, "x", "*"), "\*.*$", "*" ),
      "descending",
      cts:element-query(xs:QName("mlpm:package"),
        cts:and-query((
          cts:not-query(
            (: TODO:  cts:element-query(xs:QName("mlpm:prerelease"), cts:and-query(())) ? :)
            cts:element-value-query(xs:QName("mlpm:prerelease"), "true")),
          cts:element-range-query(xs:QName("mlpm:name"), "=", $name)))))[1]
};

declare function mlpm:find-semver(
  $package-name as xs:string,
  $semver as xs:string
) as element(mlpm:package-version)?
{
  let $latest-semver-match := mlpm:semver-latest($package-name, $semver)
  return
    if (fn:empty($latest-semver-match))
    then ()
    else
      cts:search(/mlpm:package-version,
        cts:and-query((
          cts:collection-query("http://mlpm.org/ns/collection/published"),
          cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name),
          cts:element-range-query(xs:QName("mlpm:version"), "=", $latest-semver-match)
        )),
        "unfiltered")
};

declare function mlpm:unpublished-exists($package-name as xs:string) as xs:boolean
{
  xdmp:exists(
    cts:search(/mlpm:package,
      cts:and-query((
        cts:collection-query("http://mlpm.org/ns/collection/unpublished"),
        cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name))), "unfiltered"))
};

declare function mlpm:unpublished-version-exists(
  $package-name as xs:string,
  $version as xs:string?
) as xs:boolean
{
  let $query :=
    cts:and-query((
      cts:collection-query("http://mlpm.org/ns/collection/unpublished"),
      cts:element-range-query(xs:QName("mlpm:name"), "=", $package-name),
      if (fn:not($version) or $version eq "latest") then ()
      else cts:element-range-query(xs:QName("mlpm:version"), "=", $version)
    ))
  return xdmp:exists( cts:search(/mlpm:package-version, $query, "unfiltered") )
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
        let $dep-mlpm := mlpm:find-semver($dep/mlpm:package-name/fn:string(), $dep/mlpm:semver/fn:string())
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
  mlpm:version-dir($mlpm) || $mlpm/mlpm:name || ".zip"
};

declare function mlpm:version-dir($mlpm as element(mlpm:package-version)) as xs:string
{
  mlpm:version-dir($mlpm/mlpm:name, $mlpm/mlpm:version)
};

declare function mlpm:version-dir(
  $package-name as xs:string,
  $version as xs:string
) as xs:string
{
  fn:string-join(("/packages", $package-name, "versions", $version), "/") || "/"
};

declare function mlpm:assert-valid-deps($deps as map:map?) as empty-sequence()
{
  if (fn:exists($deps))
  then
    for $dep in map:keys($deps)
    let $semver := map:get($deps, $dep)
    let $exists := fn:exists(mlpm:find-semver($dep, $semver))
    return
      if ($exists) then ()
      else fn:error(xs:QName("MISSING-DEPENDENCY"), "dependency doesn't exist", $dep || "@" || $semver)
  else ()
};

declare function mlpm:assert-valid($mlpm as json:object) as empty-sequence()
{
  let $package-name :=  map:get($mlpm, "name")
  let $version := map:get($mlpm, "version")
  return (
    mlpm:assert-valid-deps(map:get($mlpm, "dependencies")),

    if (fn:string-length($version) gt 0) then ()
    else fn:error(xs:QName("NO-VERSION"), "no version specificed", $package-name)
    (: TODO: additional validation of $mlpm :)
  )
};

declare function mlpm:authenticated(
  $username as xs:string,
  $package-name as xs:string
) as xs:boolean
{
  let $package := mlpm:find($package-name)
  return
    if (fn:not($username))
    then fn:false()
    else
      if (fn:exists($package))
      then
        if (fn:exists($package/mlpm:author))
        (: TODO: contributors :)
        then $username eq $package/mlpm:author
        else xdmp:get-current-roles() = xdmp:role("admin")
      else fn:true()
};

declare function mlpm:assert-authenticated(
  $username as xs:string,
  $package-name as xs:string
) as empty-sequence()
{
  if (mlpm:authenticated($username, $package-name)) then ()
  else
    let $msg :=
      if (fn:not($username))
      then "unknown token"
      else "$user is not allowed to modify " || $package-name
    return fn:error(xs:QName("UNPRIVILEGED"), $msg)
};

declare function mlpm:publish(
  $input as document-node(),
  $username as xs:string
) {
  let $mlpm := xdmp:from-json( xdmp:zip-get($input, "mlpm.json") )

  let $package-name :=  map:get($mlpm, "name")
  let $version := map:get($mlpm, "version")
  return (
    mlpm:assert-authenticated($username, $package-name),
    mlpm:assert-valid($mlpm),

    if (fn:exists(mlpm:find-version($package-name, $version)))
    then fn:error(xs:QName("VERSION-EXISTS"), "version already exists", ($package-name, $version))
    else
      if (mlpm:unpublished-version-exists($package-name, $version))
      then fn:error(xs:QName("UNPUBLISHED-EXISTS"), "unpublished version exists", ($package-name, $version))
      else
        let $readme := mlpm:extract-readme($input)
        return (
          mlpm:save-version($mlpm, $input),
          mlpm:save-package( mlpm:update-package($mlpm, $username, $readme) )
        )
  )
};

declare function mlpm:extract-zip-text($input as document-node(), $part as xs:string) as document-node()?
{
  let $x := xdmp:zip-get($input, $part)
  where fn:exists($x)
  return
    if ($x/node() instance of binary())
    then
      if (xdmp:binary-size($x/node()) gt 0)
      then document { xdmp:binary-decode($x, "UTF-8") }
      else ()
    else $x
};

declare function mlpm:extract-readme($input as document-node()) as document-node()?
{
  for $part in xdmp:zip-manifest($input)/zip:part
  where fn:matches($part, "^README(\.(md|mdown))?", "i")
  return mlpm:extract-zip-text($input, $part)
};

declare function mlpm:update-package(
  $mlpm as json:object,
  $username as xs:string
) as json:object
{ mlpm:update-package($mlpm, $username, ()) };

declare function mlpm:update-package(
  $mlpm as json:object,
  $username as xs:string,
  $readme as xs:string?
) as json:object
{
  let $package-name :=  map:get($mlpm, "name")
  let $version := map:get($mlpm, "version")
  let $doc := mlpm:find($package-name)
  let $clone := mlpm:json-clone($mlpm, ("version", "readme"))
  let $mlpm :=
    if ($doc)
    then
      let $old := mlpm:to-json($doc)
      return
        map:new((
          $old,
          $clone,
          map:entry("readme", $readme),
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
      let $author := (map:get($mlpm, "author"), $username)[1]
      return
        map:new((
          $clone,
          map:entry("author", $author),
          map:entry("readme", $readme),
          map:entry("versions", json:to-array($version)),
          map:entry("created", fn:current-dateTime()),
          map:entry("time", map:new((
            map:entry("created", fn:current-dateTime()),
            map:entry("modified", fn:current-dateTime()))
          ))))
  return xdmp:from-json( xdmp:to-json( $mlpm ) )
};

declare function mlpm:save-package($mlpm as json:object)
{
  let $package-name :=  map:get($mlpm, "name")
  return
    xdmp:document-insert(
      "/packages/" || $package-name || "/package.xml",
      element mlpm:package { mlpm:to-xml($mlpm) },
      $mlpm:doc-permissions,
      ("http://mlpm.org/ns/collection/published",
      "http://mlpm.org/ns/collection/package"))
};

declare function mlpm:save-version(
  $mlpm as json:object,
  $input as document-node()
)
{
  let $package-name :=  map:get($mlpm, "name")
  let $version := map:get($mlpm, "version")
  let $dir := mlpm:version-dir($package-name, $version)
  let $_ :=
    if (mlpm:semver-is-prerelease($version))
    then map:put($mlpm, "prerelease", "true")
    else ()
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
      "http://mlpm.org/ns/collection/package-version")),
    mlpm:save-version-contents($input, $dir)
  )
};

declare function mlpm:save-version-contents(
  $input as document-node(),
  $dir as xs:string
)
{
  for $part in xdmp:zip-manifest($input)/zip:part
  let $uri := $dir || "contents/" || $part
  let $file-contents := mlpm:extract-zip-text($input, $part)
  where fn:exists($file-contents)
  return
    xdmp:document-insert($uri,
      $file-contents,
      $mlpm:doc-permissions,
      ("http://mlpm.org/ns/collection/package-contents"))
};

declare function mlpm:save-readme($mlpm as element(mlpm:package-version), $readme as xs:string?)
{
  if (fn:not(fn:exists($readme))) then ()
  else
    let $package := mlpm:find($mlpm/mlpm:name)
    let $fn :=
      if (fn:exists($package/mlpm:readme))
      then xdmp:node-replace($package/mlpm:readme, ?)
      else xdmp:node-insert-child($package, ?)
    return $fn(element mlpm:readme { $readme })
};

declare function mlpm:unpublish(
  $package as element(mlpm:package),
  $version as xs:string?,
  $force-delete as xs:boolean,
  $username as xs:string
)
{
  mlpm:assert-authenticated($username, $package/mlpm:name),

  if (fn:not($version) or fn:count($package/mlpm:versions/mlpm:version) eq 1)
  then
    if ($force-delete)
    then mlpm:unpublish-all($package)
    else fn:error(xs:QName("UNPUBLISH-NO-FORCE"), "can't unpublish all without force-delete parameter")
  else
    let $package-version := mlpm:find-version($package/mlpm:name, $version)
    return (
      mlpm:unpublish-version($package-version),
      xdmp:node-delete($package/mlpm:versions/mlpm:version[. eq $version])
    )
};

declare private function mlpm:unpublish-version($package-version as element(mlpm:package-version))
{
  for $uri in (
    $package-version/fn:base-uri(.),
    mlpm:get-archive-uri($package-version)
  )
  return mlpm:unpublish-uri($uri)
};

declare private function mlpm:unpublish-all($package as element(mlpm:package))
{
  mlpm:unpublish-uri($package/fn:base-uri(.)),
  for $version in $package/mlpm:versions/mlpm:version
  let $package-version := mlpm:find-version($package/mlpm:name, $version)
  return mlpm:unpublish-version($package-version)
};


declare private function mlpm:unpublish-uri($uri as xs:string)
{
  let $collections := (
    "http://mlpm.org/ns/collection/unpublished",
    xdmp:document-get-collections($uri)[. ne "http://mlpm.org/ns/collection/published"]
  )
  return xdmp:document-set-collections($uri, $collections)
};

declare function mlpm:maven-pom($package as element(mlpm:package)) as element(mvn:project)
{
  mlpm:maven-pom($package, $package/mlpm:versions/mlpm:version[fn:last()])
};

declare function mlpm:maven-pom($package as element(mlpm:package), $version as xs:string) as element(mvn:project)
{
  mlpm:maven-pom($package, $version, fn:true())
};

declare function mlpm:maven-pom(
  $package as element(mlpm:package),
  $version as xs:string,
  $resolve-deps as xs:boolean
) as element(mvn:project)
{
  let $group-id := "com.mlpm." || ($package/mlpm:author/fn:string(), "system")[1]
  let $artifact-id := $package/mlpm:name/fn:string()
  return
    element mvn:project {
      attribute xsi:schemaLocation { "http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd" },
      element mvn:modelVersion { "4.0.0" },
      element mvn:groupId { $group-id },
      element mvn:artifactId { $artifact-id },
      element mvn:version { $version },
      element mvn:packaging { "zip" },
      if ($resolve-deps)
      then
        element mvn:dependencies {
          for $dep in $package/mlpm:dependencies/mlpm:dependency
          return
            element mvn:dependency {
              mlpm:maven-pom(
                mlpm:find( $dep/mlpm:package-name ),
                (: TODO: resolve version :)
                $dep/mlpm:semver,
                fn:false())
                /(mvn:groupId|mvn:artifactId|mvn:version)
            }
        }[./*]
      else ()
    }
};

declare function mlpm:maven-metadata($package as element(mlpm:package)) as element(metadata)
{
  let $group-id := "com.mlpm." || ($package/mlpm:author/fn:string(), "system")[1]
  let $artifact-id := $package/mlpm:name/fn:string()
  let $version := $package/mlpm:versions/mlpm:version[fn:last()]/fn:string()
  let $last-updated := fn:format-dateTime( xs:dateTime($package/mlpm:time/mlpm:modified), "[Y][M01][D01][H01][m][s][f]")
  return
    element metadata {
      element groupId { $group-id },
      element artifactId { $artifact-id },
      element version { $version },
      element versioning {
        element versions {
          for $v in $package/mlpm:versions/mlpm:version
          return element version { $v/fn:string() }
        },
        element lastUpdated { $last-updated }
      }
    }
};
