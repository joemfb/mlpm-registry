'use strict';
/*jshint node: true */

var express = require('express'),
    passport = require('passport'),
    bodyParser = require('body-parser'),
    cookieParser = require('cookie-parser'),
    expressSession = require('express-session'),
    request = require('request'),
    url = require('url'),
    GitHubStrategy = require('passport-github2').Strategy,
    MarkdownIt = require('markdown-it'),
    md = new MarkdownIt({
      html: true,
      xhtmlOut: true,
      linkify: true
    });

// auth parser fns
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

function isTokenAuth(req) {
  return (
    ( !!req.headers.authorization &&
      req.headers.authorization.split(' ')[0] === 'Token' ) ||
    !!req.query['rs:token']
  );
}

function tokenAuth(req) {
  var tokens, scheme;

  if (!req.headers.authorization) return null;

  tokens = req.headers.authorization.split(' ');
  scheme = tokens[0];

  if (scheme !== 'Token') return null;

  return { token: tokens[1] };
}

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

  passport.use(new GitHubStrategy(options.githubSettings,
    function(accessToken, refreshToken, profile, done) {
      //TODO: save gh tokens?
      createOrUpdateUser(profile, done);
    }
  ));

  // auth fns
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

  function getPrivilegedAuth() {
    return {
      user: options.privilegedUser,
      password: options.privilegedPass,
      sendImmediately: false
    };
  }

  // proxy fns
  function proxyUrl(path) {
    return url.format({
      protocol: 'http:',
      port: options.mlPort,
      hostname: options.mlHost,
      pathname: path
    });
  }

  function proxyConfig(req) {
    return {
      url: proxyUrl(req.path),
      method: req.method,
      headers: req.headers,
      qs: req.query,
      auth: isTokenAuth(req) ? getPrivilegedAuth() : getAuth(req.session || {})
    };
  }

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

  function privilegedProxy(req, res) {
    if ( isTokenAuth(req) ) {
      req.query['rs:token'] = tokenAuth(req).token;
    } else {
      req.session.user = basicAuth(req);
    }

    proxy(req).pipe(res);
  }

  function defaultProxy(req, res) {
    proxy(req).pipe(res);
  }

  // "model" fns
  function createOrUpdateUser(user, cb) {
    request({
      url: proxyUrl('/v1/resources/user'),
      method: 'POST',
      json: user,
      auth: getPrivilegedAuth()
    }, function (error, response, body)  {
      cb(error, body);
    });
  }

  function findPackagebyName(req, cb) {
    var config = proxyConfig({
      path: '/v1/search',
      headers: req.headers,
      query: {
        q: 'name:' + req.params.package,
        format: 'json',
        options: 'all'
      },
      session: req.session
    });

    config.json = true;

    request(config, function (error, response, body)  {
      if (error) return cb(error);
      cb(null, body);
    });
  }

  function saveRenderedMarkdown(uri, rendered) {
    request({
      url: proxyUrl('/v1/resources/save-readme-markdown'),
      method: 'POST',
      headers: { 'Content-type': 'text/html' },
      qs: { 'rs:uri': uri },
      body: rendered,
      auth: getPrivilegedAuth()
    }, function (error, response, body)  {
      if (error) return console.log(error);

      console.log('saved markdown for ' + uri);
    });
  }

  function getPackage(req, uri, cb) {
    var config = proxyConfig({
        path: '/v1/documents',
        headers: req.headers,
        query: {
          uri: uri,
          format: 'json',
          transform: 'mlpm'
        },
        session: req.session
      });

    config.json = true;

    request(config, function (error, response, body)  {
      if (error) return cb(error);

      body.download = '/v1/resources/download?rs:package=' + body.name +
                      '&rs:version=' + body.versions[0];

      if ( body.repository ) {
        body.repositoryName = body.repository.replace(/^https?:\/\//, '').replace(/\.git$/, '');
        body.repositoryLink = body.repository.replace(/\.git$/, '');
      }

      if ( body.readme ) {
        body['parsed-readme'] = md.render( body.readme );
        //async, deliberately ignore result
        saveRenderedMarkdown( uri, body['parsed-readme'] );
      }

      cb(null, body);
    });
  }

  // routes
  app.get('/auth/github',
    passport.authenticate('github', { scope: [ 'user:email' ] }),
    function(req, res){
      // redirected to GitHub, not called (TODO: remove?)
    });

  // github callback
  app.get('/auth/github/callback',
    passport.authenticate('github', { failureRedirect: '/login' }),
    function(req, res) {
      res.redirect('/account');
    });

  app.put('/v1/resources/publish', privilegedProxy);
  app.delete('/v1/resources/publish', privilegedProxy);

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

  app.get('/api/package/:package', function(req, res) {
    findPackagebyName(req, function(err, data) {
      if (err) {
        console.log(err);
        return res.send(500, 'error');
      }

      if (data.total === 0) return res.send(404, 'Not Found');
      if (data.total > 1)   return res.send(500, 'duplicate packages');

      getPackage( req, data.results[0].uri, function(err, packageData) {
        if (err) {
          console.log(err);
          return res.send(500, 'error');
        }
        res.send(200, packageData);
      });

    });
  });

  app.get('/maven*', function(req, res) {
    var config = {};

    req.query['rs:path'] = req.path.replace(/^\/maven/, '');

    config = proxyConfig({
      path: '/v1/resources/maven',
      method: req.method,
      headers: req.headers,
      query: req.query,
      session: req.session
    });

    config.followRedirects = true;

    req.pipe( request(config) ).pipe( res );
  });

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
