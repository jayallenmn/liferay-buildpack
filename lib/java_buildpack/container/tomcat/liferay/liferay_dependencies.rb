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
    class LiferayDependencies < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        download(@version, @uri) { |file| expand file }
        
        FileUtils.mkdir_p "#{@droplet.sandbox}/lib/ext"
        FileUtils.mv Dir.glob("#{@droplet.root}/tmp/lib-ext/*.jar"), "#{@droplet.sandbox}/lib/ext"

        FileUtils.mkdir_p "#{@droplet.sandbox}/temp/liferay/com/liferay/portal/deploy/dependencies"
        FileUtils.mv Dir.glob("#{@droplet.root}/tmp/tmp-deploy/*.jar"), "#{@droplet.sandbox}/temp/liferay/com/liferay/portal/deploy/dependencies"        
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
        with_timing "Expanding #{@component_name} to #{@droplet.root}/tmp" do
          FileUtils.mkdir_p "#{@droplet.root}/tmp"
          shell "tar xzf #{file.path} -C #{@droplet.root}/tmp 2>&1"
        end
      end

    end

  end
end
