xquery version "1.0-ml";

module namespace user = "http://mlpm.org/ns/user";

import module namespace mlpm = "http://mlpm.org/ns" at "/lib/mlpm-lib.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare namespace jsonb = "http://marklogic.com/xdmp/json/basic";

declare function user:find($username as xs:string) as element(user:user)?
{
  cts:search(/user:user, cts:element-range-query(xs:QName("user:username"), "=", $username), "unfiltered")
};

declare function user:find-by-token($token as xs:string) as element(user:user)?
{
  cts:search(/user:user, cts:element-range-query(xs:QName("user:token"), "=", $token), "unfiltered")
};

declare function user:from-json($x)
{
  typeswitch($x)
  case element(jsonb:provider) return ()
  case element(jsonb:__raw) return ()
  case element(jsonb:__json) return
    element user:github-data { $x/node() ! user:from-json(.) }
  case element(jsonb:emails) return
    element user:emails {
      $x//jsonb:value ! element user:email { fn:string(.) }
    }
  case element() return
    let $local-name :=
      fn:replace(
        fn:replace(
          fn:local-name($x), "^__", ""), "__", "-")
    where fn:not($x/@type eq "null")
    return
      element { xs:QName("user:" || $local-name) } {
        $x/node() ! user:from-json(.)
      }
  default return $x
};

declare function user:save-user($user as element(user:user))
{
  let $uri :=  "/users/" ||
    fn:exactly-one($user/user:username) || "-" ||
    fn:exactly-one($user/user:github-data/user:id) || ".xml"
  return xdmp:document-insert($uri, $user, $mlpm:doc-permissions)
};

declare function user:create-user($json as json:object) as element(user:user)
{
  (: TODO: store timestamps? :)
  let $user := user:from-json(json:transform-from-json($json))
  return
    element user:user {
      element user:name { $user/user:displayName/fn:string() },
      $user/(user:username|user:emails|user:github-data),
      user:new-token()
    }
};

declare function user:update-user($user as element(user:user), $json as json:object)
{
  (: TODO: store timestamps? :)
  let $new-user := user:from-json(json:transform-from-json($json))
  return
    element user:user {
      $user/* except $user/(user:emails|user:github-data),
      $new-user/(user:emails|user:github-data)
    }
};

declare function user:new-token() as element(user:token)
{
  element user:token {
    attribute created-at { fn:current-dateTime() },
    fn:replace(sem:uuid-string(), "-", "")
  }
};

declare function user:revoke-token($user as element(user:user)) as element(user:user)
{
  element user:user {
    $user/* except $user/(user:token|user:revoked-tokens),
    user:new-token(),
    element user:revoked-tokens {
      $user/user:revoked-tokens/*,
      element user:revoked-token {
        $user/user:token/@*,
        attribute revoked-at { fn:current-dateTime() },
        $user/user:token/fn:string()
      }
    }
  }
};

declare function user:to-json($x)
{
  typeswitch($x)
  case element(user:user) return
    xdmp:from-json(
      xdmp:to-json(
        map:new(($x/node() ! user:to-json(.)))))
  case element(user:revoked-tokens) return (
    map:entry(fn:local-name($x), json:to-array(
      for $token in $x/*
      return map:new((
        map:entry("token", $token/fn:string()),
        map:entry("revoked", $token/@revoked-at/fn:string())
      ))
    ))
  )
  (:
    TODO: assert privileged / return ()
  case element(user:token)
  case element(user:emails)
  :)
  case element() return
    map:entry(fn:local-name($x),
      if ($x/*)
      then map:new(($x/node() ! user:to-json(.)))
      else $x/node() ! user:to-json(.))
  case text() return fn:string($x)
  default return $x
};
