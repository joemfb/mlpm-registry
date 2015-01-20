/*jshint node: true */

/*
 * @author Dave Cassel - https://github.com/dmcassel
 *
 * This file configures the publicly visible server-side endpoints of your application. Work in this file to allow
 * access to parts of the MarkLogic REST API or to configure your own application-specific endpoints.
 * This file also handles session authentication, with authentication checks done by attempting to access MarkLogic.
 */

var bodyParser = require('body-parser');
var cookieParser = require('cookie-parser');
var expressSession = require('express-session');
var http = require('http');
var request = require('request');
var url = require('url');

exports.buildExpress = function(options) {
  'use strict';

  var express = require('express');
  var app = express();

  app.use(cookieParser());
  // Change this secret to something unique to your application
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


  app.get('/user/status', function(req, res) {
    if (req.session.user === undefined) {
      res.send('{"authenticated": false}');
    } else {
      res.send({
        authenticated: true,
        username: req.session.user.name,
        profile: req.session.user.profile
      });
    }
  });

  app.get('/user/login', function(req, res) {
    // Attempt to read the user's profile, then check the response code.
    // 404 - valid credentials, but no profile yet
    // 401 - bad credentials
    var login = http.get({
      hostname: options.mlHost,
      port: options.mlPort,
      path: '/v1/documents?uri=/users/' + req.query.username + '.json',
      headers: req.headers,
      auth: req.query.username + ':' + req.query.password
    }, function(response) {
      if (response.statusCode === 401) {
        res.statusCode = 401;
        res.send('Unauthenticated');
      } else if (response.statusCode === 404) {
        // authentication successful, but no profile defined
        req.session.user = {
          name: req.query.username,
          password: req.query.password
        };
        res.send(200, {
          authenticated: true,
          username: req.query.username
        });
      } else {
        if (response.statusCode === 200) {
          // authentication successful, remember the username
          req.session.user = {
            name: req.query.username,
            password: req.query.password
          };
          response.on('data', function(chunk) {
            var json = JSON.parse(chunk);
            if (json.user !== undefined) {
              req.session.user.profile = {
                fullname: json.user.fullname,
                emails: json.user.emails
              };
              res.send(200, {
                authenticated: true,
                username: req.query.username,
                profile: req.session.user.profile
              });
            } else {
              console.log('did not find chunk.user');
            }
          });
        }
      }
    });

    login.on('error', function(e) {
      console.log('login failed: ' + e.message);
      res.status(500).send(e);
    });
  });

  app.get('/user/logout', function(req, res) {
    delete req.session.user;
    res.send();
  });

  // optional basic auth, for cmd-line client
  app.put('/v1/resources/publish', function(req, res) {
    var auth64, credentials, index;
    if ( !req.session.user ) {
      auth64 = req.headers.authorization.split(' ')[1];
      credentials = new Buffer(auth64, 'base64').toString();
      index = credentials.indexOf(':');
      req.session.user = {
        username: credentials.slice(0, index),
        password: credentials.slice(index + 1)
      };
    }

    proxy(req).pipe(res);
  });

  // ==================================
  // MarkLogic REST API endpoints
  // ==================================
  // For any other GET request, proxy it on to MarkLogic.
  app.get('/v1*', function(req, res) {
    proxy(req).pipe(res);

    // To require authentication before getting to see data, use this:
    // if (req.session.user === undefined) {
    //   res.send(401, 'Unauthorized');
    // } else {
    //   proxy(req, res);
    // }
    // -- end of requiring authentication

  });

  app.put('/v1*', function(req, res) {

    // For PUT requests, require authentication
    // if (req.session.user === undefined) {
    //   res.send(401, 'Unauthorized');
    // } else

    if (req.path === '/v1/documents' &&
      req.query.uri.match('/users/') &&
      req.query.uri.match(new RegExp('/users/[^(' + req.session.user.name + ')]+.json'))) {
      // The user is try to PUT to a profile document other than his/her own. Not allowed.
      res.send(403, 'Forbidden');
    } else {
      if (req.path === '/v1/documents' && req.query.uri.match('/users/')) {
        // TODO: The user is updating the profile. Update the session info.
      }
      proxy(req).pipe(res);
    }
  });

  app.post('/v1*', function(req, res) {
    proxy(req).pipe(res);

    // Require authentication for POST requests
    // if (req.session.user === undefined) {
    //   res.send(401, 'Unauthorized');
    // } else {
    //   proxy(req).pipe(res);
    // }
  });

  // Require authentication for DELETE requests
  app.delete('/v1*', function(req, res) {
    if (req.session.user === undefined) {
      res.send(401, 'Unauthorized');
    } else {
      proxy(req).pipe(res);
    }
  });

  app.use(express.static('ui/app'));
  app.use('/', express.static('ui/app'));
  app.use('/*', express.static('ui/app'));

  return app;
};

