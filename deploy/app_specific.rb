#
# Put your custom functions in this class in order to keep the files under lib untainted
#
# This class has access to all of the stuff in deploy/lib/server_config.rb
#
class ServerConfig

  alias_method :original_deploy_modules, :deploy_modules

  def deploy_modules
    original_deploy_modules

    # TODO: pull request: https://github.com/marklogic/roxy/blob/dev/deploy/lib/server_config.rb#L576
    execute_query(%Q{
      cts:uri-match("*.xqy") ! xdmp:document-add-permissions(., (
        xdmp:permission("rest-reader", "execute"),
        xdmp:permission("rest-admin", "read"),
        xdmp:permission("rest-admin", "update")
      ))
    },
    :db_name => @properties["ml.app-modules-db"])
  end

end