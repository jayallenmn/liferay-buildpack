# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/container'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat logging support.
    class LiferayPortal < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        download(@version, @uri) { |file| expand file }

        configure_mysql_service
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def tar_name
        "liferay-portal-tomcat-6.2-ce-ga5-dependencies.tar.gz"
      end

      def expand(file)
        with_timing "Expanding #{@component_name} to #{@droplet.sandbox}" do
          shell "tar xzf #{file.path} -C #{@droplet.sandbox} 2>&1"
        end
      end

      # In this method we check if the application is bound to a service. If that is the case then we create the portal-ext.properties
      # and store it in Liferay Portal classes directory.
      def configure_mysql_service

          @logger       = JavaBuildpack::Logging::LoggerFactory.instance.get_logger TomcatInstance
          service       = @application.services.find_service FILTER

          @logger.info{ "--->Application seems to be bound to a lf-mysqldb service" }

          if service.to_s ==''
            @logger.warn{'--->No lf-mysqldb SERVICE FOUND'}
          else
              @logger.info{ "--->Configuring MySQL Store for Liferay" }

              file = "#{@droplet.sandbox}/webapps/ROOT/WEB-INF/classes/portal-ext.properties"

              if File.exist? (file)
                  @logger.info {"--->Portal-ext.properties file already exist, so skipping MySQL configuration" }
              else
                  with_timing "Creating portal-ext.properties in #{file}" do

                      credentials   = service['credentials']
                      @logger.debug{ "--->credentials:#{credentials} found" }
                      
                      host_name     = credentials['hostname']
                      username      = credentials['username']
                      password      = credentials['password']
                      db_name       = credentials['name']
                      port          = credentials['port']


                      jdbc_url      = "jdbc:mysql://#{host_name}:#{port}/#{db_name}"
                      #jdbc_url      = "jdbc:mysql://#{host_name}:#{port}"
                      @logger.info {"--->  jdbc_url_name:  #{jdbc_url} \n"}
                      @logger.debug {"--->  username:  #{username} \n"}


                      File.open(file, 'w') do  |file| 
                        file.puts("#\n")
                        file.puts("# MySQL\n")
                        file.puts("#\n")

                        file.puts("jdbc.default.driverClassName=com.mysql.jdbc.Driver\n")
                        file.puts("jdbc.default.url=" + jdbc_url + "\n")
                        file.puts("jdbc.default.username=" + username + "\n")
                        file.puts("jdbc.default.password=" + password + "\n")

                        @logger.info {"--->  Port:  #{port} \n"}
                        
                        file.puts("#\n")
                        file.puts("# Configuration Connextion Pool\n") # This should be configurable through ENV
                        file.puts("#\n")
                        file.puts("jdbc.default.acquireIncrement=5\n")
                        file.puts("jdbc.default.connectionCustomizerClassName=com.liferay.portal.dao.jdbc.pool.c3p0.PortalConnectionCustomizer\n")
                        file.puts("jdbc.default.idleConnectionTestPeriod=60\n")
                        file.puts("jdbc.default.maxIdleTime=3600\n")

                        #Check if the user specify a maximum pool size
                        user_max_pool = ENV["LIFERAY_MAX_POOL_SIZE"]
                        if user_max_pool ==""
                          file.puts("jdbc.default.maxPoolSize=100\n") #This is the default value from Liferay
                          @logger.info {"--->  No value set for LIFERAY_MAX_POOL_SIZE so taking the default (100) \n"}
                        else
                          file.puts("jdbc.default.maxPoolSize=" + user_max_pool + "\n")
                          @logger.info {"--->  LIFERAY_MAX_POOL_SIZE:  #{user_max_pool} \n"}
                        end
                        file.puts("jdbc.default.minPoolSize=10\n")
                        file.puts("jdbc.default.numHelperThreads=3\n")


                        file.puts("#\n")
                        file.puts("# Configuration of the auto deploy folder\n")
                        file.puts("#\n")
                        file.puts("auto.deploy.dest.dir=${catalina.home}/webapps\n")
                        file.puts("auto.deploy.deploy.dir=${catalina.home}/deploy\n")
                        file.puts("#\n")
                        
                        file.puts("setup.wizard.enabled=false\n")
                        
                        file.puts("#\n")
                        file.puts("auth.token.check.enabled=false\n")
                        
                      
                        file.puts("# Configuration of the media library\n")
                        file.puts("#\n")
                        file.puts("dl.store.impl=com.liferay.portlet.documentlibrary.store.DBStore\n")
                        
                        file.puts("# Configuration of Quartz\n")
                        file.puts("#\n")
                        file.puts("org.quartz.jobStore.isClustered=true\n")
                        
                        @logger.info {"--->  configuring Cluster \n"}
               
                        file.puts("# Configuration of Cluster Link\n")
                        file.puts("#\n")
                        file.puts("cluster.link.enabled=true\n")
                        host_port = "#{host_name}:#{port}"
                        file.puts("cluster.link.autodetect.address=" + host_port +"\n")
                        
                        #@logger.info {"--->  Disabling Caching \n"}
                        #file.puts("browser.cache.disabled=true\n")
                        
                        
                        @logger.info {"--->  Configuring unicast \n"}
                        file.puts("# Configuration of Unicast\n")
                        file.puts("#\n")
                        file.puts("cluster.link.enabled=cluster.link.channel.properties.control=unicast.xml\n")
                        file.puts("cluster.link.channel.properties.transport.0=unicast.xml\n")
                        file.puts("ehcache.bootstrap.cache.loader.factory=com.liferay.portal.cache.ehcache.JGroupsBootstrapCacheLoaderFactory\n")
                        file.puts("ehcache.cache.event.listener.factory=net.sf.ehcache.distribution.jgroups.JGroupsCacheReplicatorFactory\n")
                        file.puts("ehcache.cache.manager.peer.provider.factory=net.sf.ehcache.distribution.jgroups.JGroupsCacheManagerPeerProviderFactory\n")
                        file.puts("net.sf.ehcache.configurationResourceName.peerProviderProperties=file=/unicast.xml\n")
                        file.puts("ehcache.multi.vm.config.location.peerProviderProperties=file=/unicast.xml\n")
                        
                      end
                  end # end with_timing
              end
          end
      end
  end
end
