(function () {
  'use strict';

  angular.module('mlpm.package')
    .controller('PackageCtrl', PackageCtrl);

  PackageCtrl.$inject = ['$scope', '$http', '$routeParams', '$sce'];

  function PackageCtrl($scope, $http, $routeParams, $sce) {
    var model = {
      detail: {}
    };

    $http.get('/api/package/' + $routeParams.package).then(function(response) {
      model.detail = response.data;
      model.readme = $sce.trustAsHtml(model.detail['parsed-readme']);
    });

    angular.extend($scope, {
      model: model
    });
  }
}());
