'use strict';
/*jshint node: true */

var express = require('express'),
    passport = require('passport'),
    bodyParser = require('body-parser'),
    cookieParser = require('cookie-parser'),
    expressSession = require('express-session'),
    request = require('request'),
    url = require('url'),
    GitHubStrategy = require('passport-github2').Strategy;

function buildExpress(options) {
  var app = express();

  app.use(cookieParser());
  app.use(expressSession({
    secret: 'mkXb{1kA\\#4-vxnaA,r6s~v5Avv<$V$K',
    saveUninitialized: true,
    resave: true
  }));
  app.use(bodyParser.raw({
    type: 'application/zip',
    limit: '50mb'
  }));
  app.use(bodyParser.json());
  app.use(bodyParser.urlencoded({ extended: true }));

  // TODO: save/get from ML?
  passport.serializeUser(function(user, done) {
    done(null, user);
  });
  passport.deserializeUser(function(obj, done) {
    done(null, obj);
  });

  app.use(passport.initialize());
  app.use(passport.session());

  function getPrivilegedAuth() {
    return {
      user: options.privilegedUser,
      password: options.privilegedPass,
      sendImmediately: false
    };
  }

  function createOrUpdateUser(user, cb) {
    request({
      url: url.format({
        protocol: 'http:',
        port: options.mlPort,
        hostname: options.mlHost,
        pathname: '/v1/resources/user'
      }),
      method: 'POST',
      json: user,
      auth: getPrivilegedAuth()
    }, function (error, response, body)  {
      cb(error, body);
    });
  }

  passport.use(new GitHubStrategy(options.githubSettings,
    function(accessToken, refreshToken, profile, done) {
      //TODO: save gh tokens?
      createOrUpdateUser(profile, done);
    }
  ));

  app.get('/auth/github',
    passport.authenticate('github', { scope: [ 'user:email' ] }),
    function(req, res){
      // redirected to GitHub, not called (TODO: remove?)
    });

  // github callback
  app.get('/auth/github/callback',
    passport.authenticate('github', { failureRedirect: '/login' }),
    function(req, res) {
      res.redirect('/profile');
    });

  function getAuth(session) {
    var auth = { sendImmediately: false };

    if ( session.user && session.user.username && session.user.password ) {
      auth.user = session.user.username;
      auth.pass = session.user.password;
    } else {
      auth.user = options.defaultUser;
      auth.pass = options.defaultPass;
    }

    return auth;
  }

  function basicAuth(req) {
    var auth64, credentials, index;

    if (!req.headers.authorization) return null;

    auth64 = req.headers.authorization.split(' ')[1];
    credentials = new Buffer(auth64, 'base64').toString();
    index = credentials.indexOf(':');

    return {
      username: credentials.slice(0, index),
      password: credentials.slice(index + 1)
    };
  }

  // TODO:
  //   proxy all requests with rest-reader only
  //   (so no API methods need to be session-protected)
  function proxyConfig(req) {
    return {
      url: url.format({
        protocol: 'http:',
        port: options.mlPort,
        hostname: options.mlHost,
        pathname: req.path
      }),
      method: req.method,
      headers: req.headers,
      qs: req.query,
      auth: getAuth(req.session)
    };
  }

  // Generic proxy function used by multiple HTTP verbs
  function proxy(req) {
    var config = proxyConfig(req);

    if (req.body !== undefined) {
      if ( req.headers['content-type'] === 'application/zip' ) {
        config.body = req.body;
      } else {
        config.body = JSON.stringify(req.body);
      }
    }

    return req.pipe( request(config) );
  }

  // optional basic auth, for cmd-line client
  function basicAuthProxy(req, res) {
    var auth;

    if ( !req.session.user ) {
      auth = basicAuth(req);
      if ( !auth ) {
        return res.send(401, 'Unauthorized');
      }
      req.session.user = auth;
    }

    proxy(req).pipe(res);
  }

  // TODO:
  //   check for Token (or Basic?) auth on /publish
  //   (don't proxy, use node-client db.invoke?)
  app.put('/v1/resources/publish', basicAuthProxy);
  app.post('/v1/resources/unpublish', basicAuthProxy);

  // TODO: rewrite user handling
  // /user/status retrieves user from ML by id
  app.get('/user/status', function(req, res) {
    var user = req.session.passport.user || req.session.user || null;

    res.send(200, { authenticated: !!user, user: user });
  });

  app.get('/user/logout', function(req, res) {
    req.logout();
    //TODO: still necessary?
    delete req.session.user;
    //TODO: send response?
    res.send();
  });

  function defaultProxy(req, res) {
    proxy(req).pipe(res);
  }

  // ==================================
  // MarkLogic REST API endpoints
  // ==================================

  app.get('/v1*', defaultProxy);
  app.post('/v1*', defaultProxy);
  app.put('/v1*', defaultProxy);
  app.delete('/v1*', defaultProxy);

  // TODO: require authentication && URI filtering for PUT/DELETE requests

  // if (req.session.user === undefined) {
  //   res.send(401, 'Unauthorized');
  // }

  // if (req.path === '/v1/documents' &&
  //     req.query.uri.match('/users/') &&
  //     req.query.uri.match(new RegExp('/users/[^(' + req.session.user.name + ')]+.json'))) {
  //     // The user is try to PUT to a profile document other than his/her own. Not allowed.
  //     res.send(403, 'Forbidden');

  app.use(express.static('ui/app'));
  app.use('/', express.static('ui/app'));
  app.use('/*', express.static('ui/app'));

  return app;
}

module.exports.buildExpress = buildExpress;
