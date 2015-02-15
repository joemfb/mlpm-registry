xquery version "1.0-ml";

module namespace user = "http://mlpm.org/ns/user";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

declare namespace jsonb = "http://marklogic.com/xdmp/json/basic";

declare function user:find($username as xs:string) as element(user:user)?
{
  cts:search(/user:user, cts:element-range-query(xs:QName("user:username"), "=", $username), "unfiltered")
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
  return xdmp:document-insert($uri, $user)
};

declare function user:create-user($json as json:object) as element(user:user)
{
  let $user := user:from-json(json:transform-from-json($json))
  return
    element user:user {
      element user:name { $user/user:displayName/fn:string() },
      $user/(user:username|user:emails|user:github-data),
      element user:tokens {
        element user:token {
          attribute active { "true" },
          attribute created-at { fn:current-dateTime() },
          fn:replace(sem:uuid-string(), "-", "")
        }
      }
    }
};

declare function user:update-user($user as element(user:user), $json as json:object)
{
  let $new-user := user:from-json(json:transform-from-json($json))
  return
    element user:user {
      $user/* except $user/(user:emails|user:github-data),
      $new-user/(user:emails|user:github-data)
    }
};

declare function user:to-json($x)
{
  typeswitch($x)
  case element(user:user) return
    xdmp:from-json(
      xdmp:to-json(
        map:new(($x/node() ! user:to-json(.)))))
  case element(user:tokens) return
    user:to-json(
      fn:exactly-one($x/user:token[@active eq "true"]))
  case element() return
    map:entry(fn:local-name($x),
      if ($x/*)
      then map:new(($x/node() ! user:to-json(.)))
      else $x/node() ! user:to-json(.))
  case text() return fn:string($x)
  default return $x
};
