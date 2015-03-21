(function () {
  'use strict';

  angular.module('mlpm.package')
    .controller('PackageCtrl', PackageCtrl);

  PackageCtrl.$inject = ['$scope', '$http', '$routeParams', '$sce'];

  function PackageCtrl($scope, $http, $routeParams, $sce) {
    var model = {
      detail: {},
      shortReadme: false,
      readme: null
    };

    $http.get('/api/package/' + $routeParams.package).then(function(response) {
      model.detail = response.data;
      model.detail.dependencies = _.map(model.detail.dependencies, function(version, dependency) {
        return { version: version, name: dependency };
      });

      if (model.detail['parsed-readme']) {
        model.shortReadme = model.detail['parsed-readme'].length < 500;
        model.readme = $sce.trustAsHtml(model.detail['parsed-readme']);
      } else {
        model.shortReadme = true;
      }
    });

    angular.extend($scope, {
      model: model
    });
  }
}());
