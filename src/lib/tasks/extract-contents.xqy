xquery version "1.0-ml";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";

declare namespace zip = "xdmp:zip";

declare function local:save-readme($mlpm as element(mlpm:package-version), $readme as xs:string?)
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

declare function local:extract-version($mlpm as element(mlpm:package-version))
{
  let $archive := fn:doc(mlpm:get-archive-uri($mlpm))
  let $dir := mlpm:version-dir($mlpm)
  let $readme := mlpm:extract-readme($archive)
  return (
    mlpm:save-version-contents($archive, $dir),
    local:save-readme($mlpm, $readme)
  )
};

for $v in /mlpm:package-version
where fn:not(xdmp:exists(xdmp:directory(mlpm:version-dir($v) || "/contents/", "infinity")))
return local:extract-version($v)
