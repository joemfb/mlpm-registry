(function () {
  'use strict';

  angular.module('mlpm.user')
    .controller('AccountCtrl', AccountCtrl);

  AccountCtrl.$inject = ['$scope', 'User', '$location', 'MLRest'];

  function AccountCtrl($scope, user, $location, mlRest) {
    var model = {
      user: user,
      systemPackages: [],
      alerts: []
    };

    (function init() {
      $scope.$watch('model.user.loaded', function(newValue) {
        if ( user.loaded && !user.authenticated ) {
          $location.path('/');
        }

        if (user.authenticated) {
          getSystemPackages();
        }
      });
    })();

    function getSystemPackages() {
      mlRest.extension('system-packages', {
        params: { 'rs:username': user.username }
      }).then(function(response) {
        model.systemPackages = response.data;
      });
    }

    function claimPackage(packageObj) {
      mlRest.extension('system-packages', {
        method: 'POST',
        params: {
          'rs:uri': packageObj.uri,
          'rs:username': user.username
        }
      }).then(function(response) {
        model.alerts.push({
          type: 'success',
          msg: 'you\'ve successfully claimed ' + packageObj.name + '!'
        })
        getSystemPackages();
      });
    }

    angular.extend($scope, {
      model: model,
      claimPackage: claimPackage,
      closeAlert: function closeAlert(index) {
        model.alerts.splice(index, 1);
      }
    });
  }

}());
