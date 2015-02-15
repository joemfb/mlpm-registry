/*jshint node: true */

'use strict';

/*
 * @author Dave Cassel - https://github.com/dmcassel
 *
 * This file contains the Gulp tasks you can run. As written, you'll typically run two processes :
 * $ gulp
 * - this will watch the file system for changes, running JSHint, compiling lesscss.js files, and minifying JS
 * $ gulp server
 * - run a node server, hosting the AngularJS application
 */

var gulp = require('gulp');

var argv = require('yargs').argv;
var concat = require('gulp-concat');
var fs = require('fs');
var jshint = require('gulp-jshint');
var less = require('gulp-less');
var karma = require('karma').server;
var path = require('path');
var rename = require('gulp-rename');
var uglify = require('gulp-uglify');

var options = {
  appPort: argv['app-port'] || 8096,
  mlHost: argv['ml-host'] || 'localhost',
  mlPort: argv['ml-port'] || 8094,

  // TODO: set default rest-reader privileged rest-writer
  defaultUser: 'mlpm-registry-user',
  defaultPass: 'K#Xbbr\'OE1py7w`FE>Ai',
  privilegedUser: 'admin',
  privilegedPass: 'admin',

  githubSettings: {
    clientID: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
    callbackURL: process.env.GITHUB_CLIENT_CALLBACK
  }
};

gulp.task('jshint', function() {
  gulp.src([
      './server.js',
      './gulpfile.js',
      'ui/app/**/*.js',
      '!ui/app/bower_components/**/*.js'
    ])
    .pipe(jshint())
    .pipe(jshint.reporter('default'));
});

// Compile Our Less
gulp.task('less', function() {
  return gulp.src('ui/app/styles/*.less')
    .pipe(less())
    .pipe(gulp.dest('ui/app/styles/'));
});

// Concatenate & Minify JS
gulp.task('scripts', function() {
  return gulp.src([
      './ui/app/**/*.js',
      '!ui/app/bower_components/**/*.js'
    ])
    .pipe(concat('all.js'))
    .pipe(gulp.dest('dist'))
    .pipe(rename('all.min.js'))
    .pipe(uglify())
    .pipe(gulp.dest('dist'));
});

// Watch Files For Changes
gulp.task('watch', function() {
  gulp.watch([
      './server.js',
      './gulpfile.js',
      'ui/app/**/*.js',
      '!ui/app/bower_components/**/*.js',
    ], ['jshint', 'scripts']);
  gulp.watch('./ui/app/styles/*.less', ['less']);
});

gulp.task('test', function() {
  karma.start({
    configFile: path.join(__dirname, './karma.conf.js'),
    singleRun: true,
    autoWatch: false
  }, function (exitCode) {
    console.log('Karma has exited with ' + exitCode);
    process.exit(exitCode);
  });
});

gulp.task('autotest', function() {
  karma.start({
    configFile: path.join(__dirname, './karma.conf.js'),
    autoWatch: true
  }, function (exitCode) {
    console.log('Karma has exited with ' + exitCode);
    process.exit(exitCode);
  });
});

gulp.task('server', function() {
  var server = require('./server.js').buildExpress(options);
  server.listen(options.appPort);
  fs.writeFileSync('gulp-default.pid', process.pid.toString(), 'ascii');
});

// Default Task
gulp.task('default', ['jshint', 'less', 'scripts', 'watch', 'server']);
